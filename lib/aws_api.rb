#-*- encoding: utf-8 -*-

require 'rest-client'
require 'aws-sdk'
require 'yaml'

# Aws APIのラッパーを提供します。
class AwsApi

  KEYPAIR_DIR = "#{ENV['HOME']}/.oc/keypairs"
  AMI_DEFAULT = "ami-9a2fb89a" # Amazon Linux 2015.09

  def initialize(profile, credentials_path = nil, config_path = nil, client = nil)
    @profile = profile

    if credentials_path.nil? and config_path.nil?
      @credentials = AwsConfig.load_credentials(profile)
    else
      @credentials = AwsConfig.load_credentials(profile, credentials_path, config_path)
    end

    @profile_filters = [
      { name: "tag:Profile", values: [@profile] },
    ]

    if client.nil?
      @ec2 = Aws::EC2::Client.new
    else
      @ec2 = client
    end
  end

  def profile_private_key
    "#{KEYPAIR_DIR}/#{@profile}.pem"
  end

  # VPCを初期構築します。
  def init_vpc(cidr, subnets)

    # Profileに該当するVPCが無いことのチェック
    resp = @ec2.describe_vpcs({ filters: @profile_filters })
    onerror_response(resp, "vpc describe")
    raise Thor::Error, "already vpc created vpc-#{@profile}" if !resp.vpcs.empty?

    # VPC作成
    resp = @ec2.create_vpc({
      cidr_block: cidr,
      instance_tenancy: "default",
    })
    onerror_response(resp, "vpc create")

    begin
      vpc_id = resp.vpc.vpc_id

      # タグ付け
      set_default_tag("vpc", vpc_id)

      # RouteTable タグ作成
      route_table_id = nil
      resp = @ec2.describe_route_tables({ filters: [ { name: "vpc-id", values: [vpc_id] } ]})
      resp.on_success do
        resp.route_tables.each_with_index do |route_table, index|
          route_table_id = route_table.route_table_id
          set_default_tag("routetable-#{index}", route_table_id)
        end
      end

      # Gateway 作成
      resp = @ec2.create_internet_gateway({})
      onerror_response(resp, "gateway create #{vpc_id}")
      gateway_id = resp.internet_gateway.internet_gateway_id
      set_default_tag("gateway", gateway_id)

      # Gateway アタッチ
      resp = @ec2.attach_internet_gateway({ internet_gateway_id: gateway_id, vpc_id: vpc_id })
      onerror_response(resp, "gateway attach #{gateway_id} to #{vpc_id}")

      # RouteTableにGatewayをルーティング
      resp = @ec2.create_route({
        gateway_id: gateway_id,
        route_table_id: route_table_id,
        destination_cidr_block: "0.0.0.0/0"
      })
      onerror_response(resp, "routing create #{gateway_id} to #{route_table_id}")

      # Subnet 作成
      subnets.each do |subnet|
        resp = @ec2.create_subnet({
          vpc_id: vpc_id,
          cidr_block: subnet[:cidr],
          availability_zone: @credentials[:region] + "a"
        })
        onerror_response(resp, "subnet create #{subnet[:cidr]}")
        subnet_id = resp.subnet.subnet_id
        set_default_tag(subnet[:name], subnet_id)

        # グローバルIPの自動割り当てを有効化
        if subnet[:auto_ip]
          resp = @ec2.modify_subnet_attribute({
            subnet_id: subnet_id,
            map_public_ip_on_launch: { value: true }
          })
          onerror_response(resp, "subnet map_public_ip_on_launch #{subnet[:cidr]}")

          # publicタグ付け
          @ec2.create_tags({
            resources: [subnet_id],
            tags: [
              { key: "Subnet", value: "public" },
            ]
          })
        end

        # RouteTableとSubnetを関連づけ
        resp = @ec2.describe_route_tables({ filters: @profile_filters })
        onerror_response(resp, "route table describe #{@profile}")
        resp.on_success do
          resp.route_tables.each do |route|
            _resp = @ec2.associate_route_table({
              subnet_id: subnet_id,
              route_table_id: route.route_table_id
            })
            onerror_response(_resp, "associate #{subnet_id} -> #{route.route_table_id}")
          end
        end
      end

      # Security Groupの作成
      sec_groups = [
        { name: "basic-login", desc: "arrow ssh", rules: [ "in/tcp/22/client" ] },
        { name: "basic-http", desc: "arrow http", rules: [ "in/tcp/80/all", "in/tcp/443/all" ] },
        { name: "basic-onlyme", desc: "arrow http", rules: [ "in/all/all/client" ] },
      ]

      sec_groups.each do |group|
        create_security_group(group[:name], group[:rules], group[:desc], vpc_id)
      end

      # キーペアの初期化
      create_keypairs

      $log.info "Profile(#{@profile}) preparing successful!"
    rescue => e
      $log.error "An error occurred: #{e}. vpc deleting."
      e.backtrace.each do |line|
        puts "\t#{line}"
      end

      # clean vpc
      delete_vpc
      
      raise Thor::Error, "create vpc failure: #{e}"
    end
  end

  # セキュリティグループを作成します。
  #
  # rules: [in/out]/[tcp/udp/-1]/[port/-1]/[ip_address/all/client]
  def create_security_group(name, rules, desc = "description", vpc_id = nil)

    if vpc_id.nil?
      vpc_id = get_vpc_id
    end

    resp = @ec2.create_security_group({
      group_name: "#{@profile}-#{name}",
      description: "#{name} servers.",
      vpc_id: vpc_id
    })
    onerror_response(resp, "security group create #{name}")
    group_id = resp.group_id
    set_default_tag(name, group_id)

    # add security group rules.
    rules.each do |rule|
      type, proto, from_port, to_port, cidr = expand_firewall_rule(rule)
      
      opts = {
        group_id: group_id,
        ip_protocol: proto,
        from_port: from_port,
        to_port: to_port,
        cidr_ip: cidr
      }

      $log.info "create security group={ type:#{type} proto:#{proto} port:#{from_port}-#{to_port} cidr:#{cidr} }"
      if type == "in"
        resp = @ec2.authorize_security_group_ingress(opts)
      elsif type == "out"
        resp = @ec2.authorize_security_group_egress(opts)
      end

      onerror_response(resp, "add security rule #{rule} to #{group_id}")
    end
  end

  # 指定したSecurity groupを削除する
  def delete_security_group(name)

    resp = @ec2.describe_security_groups({ filters: @profile_filters })
    resp.on_success do
      resp.security_groups.each do |group|
        if "#{@profile}-#{name}" == group.group_name
          group_id = group.group_id
          _resp = @ec2.delete_security_group({ group_id: group_id })
          onerror_response(_resp, "security group delete #{group_id}")
        end
      end
    end

  end

  # VPCを削除します。
  def delete_vpc

    vpc_id = get_vpc_id

    if vpc_id.nil?
      raise Thor::Error, "vpc not found profile: #{@profile}"
    end
     
    # EC2を削除する
    shutdown_instances(nil, true)

    # Security groupを削除する
    resp = @ec2.describe_security_groups({ filters: @profile_filters })
    resp.on_success do
      resp.security_groups.each do |group|
        group_id = group.group_id
        _resp = @ec2.delete_security_group({ group_id: group_id })
        onerror_response(_resp, "security group delete #{group_id}")
      end
    end

    # Subnetを削除する
    resp = @ec2.describe_subnets({ filters: @profile_filters })
    resp.on_success do
      resp.subnets.each do |subnet|
        subnet_id = subnet.subnet_id
        _resp = @ec2.delete_subnet({ subnet_id: subnet_id })
        onerror_response(_resp, "subnet delete #{subnet_id}")
      end
    end

    # Gatewayを削除する
    resp = @ec2.describe_internet_gateways({ filters: @profile_filters })
    resp.on_success do
      resp.internet_gateways.each do |gateway|
        gateway_id = gateway.internet_gateway_id

        _resp = @ec2.detach_internet_gateway({ internet_gateway_id: gateway_id, vpc_id: vpc_id })
        onerror_response(_resp, "internet_gateway detach #{gateway_id} to #{vpc_id}")

        _resp = @ec2.delete_internet_gateway({ internet_gateway_id: gateway_id })
        onerror_response(_resp, "internet_gateway delete #{gateway_id}")
      end
    end

    # VPCを削除する
    resp = @ec2.delete_vpc({ vpc_id: vpc_id })
    onerror_response(resp, "vpc delete #{vpc_id}")

    # キーペアの削除
    remove_kaypairs
  end

  # EC2で使用するキーペアを初期化します。
  def create_keypairs
    resp = @ec2.create_key_pair({ key_name: "#{@profile}-key" })
    onerror_response(resp, "keypair #{@profile}-key delete")

    # keypair ディレクトリにキーを保存する。
    FileUtils.mkdir_p(KEYPAIR_DIR) unless File.exists?(KEYPAIR_DIR)
    File.write(profile_private_key, resp.key_material)
    File.chmod(0600, profile_private_key)

    $log.info "#{profile_private_key} saved!"
  end

  # EC2で使用するキーペアを削除します。
  def remove_kaypairs
    resp = @ec2.delete_key_pair({ key_name: "#{@profile}-key" })
    onerror_response(resp, "keypair #{@profile}-key delete")

    File.delete(profile_private_key) if File.exists?(profile_private_key)
  end

  # インスタンスを起動します。
  def create_instances(type, role, num)
    # ロール設定を読み込む
    role_config = RoleConfig.load(role)

    if !role_config['image']
      raise Thor::Error, "require role_config['image'] !"
    end

    # subnetを取得
    subnet_id = nil
    resp = @ec2.describe_subnets({ filters: get_filter_options({ name: "tag:Subnet", values: ["public"] }) })
    onerror_response(resp, "subnet describe")
    resp.subnets.each do |subnet|
      subnet_id = subnet.subnet_id
    end

    # security groupを取得
    sg_names = role_config["firewall"].map{|name| "#{@profile}-#{name}" }
    resp = @ec2.describe_security_groups({ filters: get_filter_options({ name: "tag:Name", values: sg_names }) })
    onerror_response(resp, "security groups describe")
    sg_list = resp.security_groups.map {|sg| sg.group_id }

    # iam roleを設定
    iam_role = nil
    if role_config['iam_role']
      iam_role = { name: role_config['iam_role'].split("/").last }
    end

    $log.info "  image: #{role_config['image']}"
    $log.info "  role: #{role}"
    $log.info "  subnet: #{subnet_id}"
    $log.info "  securiy: #{sg_list}"
    $log.info "  device: #{role_config['devices_mapping']}"
    $log.info "  iam role: #{iam_role}"

    resp = @ec2.run_instances({
      image_id: role_config['image'],
      min_count: num,
      max_count: num,
      instance_type: type,
      key_name: "#{@profile}-key",
      security_group_ids: sg_list,
      subnet_id: subnet_id,
      block_device_mappings: role_config['devices_mapping'],
      iam_instance_profile: iam_role,
    })
    onerror_response(resp, "instance create #{type}:#{role}")

    resp.instances.each do |instance|
      instance_id = instance.instance_id
      set_default_tag(role, instance_id)
      @ec2.create_tags({
        resources: [instance_id],
        tags: [
          { key: "Role", value: role },
        ]
      })
    end
  end

  # 停止中のインスタンスを起動する
  def start_instances(role)
    instances = find_instances(role, :stopped)

    if instances.empty?
      raise Thor::Error, "target instance not found"
    end

    ids = instances.map{|i| i[:id] }
    names = instances.map do |instance|
      instance[:name] + ":" + instance[:id]
    end

    $log.info "starting instances: #{names}"

    resp = @ec2.start_instances({
      instance_ids: ids
    })
    onerror_response(resp, "instance start #{role}")
  end

  # インスタンスを停止・削除する
  def shutdown_instances(role, terminate)
    instances = find_instances(role, :noterminate)
    ids = instances.map{|i| i[:id] }
    names = instances.map{|i| i[:name] + ":" + i[:id] }

    if ids.size > 0
      if !terminate
        resp = @ec2.stop_instances({ instance_ids: ids })
        onerror_response(resp, "stop instances: #{names}")
      else
        resp = @ec2.terminate_instances({ instance_ids: ids })
        onerror_response(resp, "terminate instances: #{names}")
      end
    else
      $log.warn "対象のインスタンスがありませんでした"
    end
  end

  # 指定の条件でインスタンスを検索する
  def find_instances(role, state = :running)
    filters = get_filter_options([])

    case state
    when :running
      filters << { name: "instance-state-name", values: ["running"] } # 稼働中のインスタンスのみ対象
    when :stopped
      filters << { name: "instance-state-name", values: ["stopped"] } # 稼働中のインスタンスのみ対象
    when :noterminate
      filters << { name: "instance-state-name", values: ["pending", "running", "shutting-down", "stopping", "stopped"] } # 未terminateをすべて対象
    when :all
    end

    if !role.nil?
      filters << { name: "tag:Role", values: [role] }
    end

    # インスタンスを抽出
    instances = []
    resp = @ec2.describe_instances({ filters: filters })
    onerror_response(resp, "desc instances")
    resp.reservations.each do |reserve|
      reserve.instances.each do |instance|
        instance = {
          id: instance.instance_id,
          name: instance.tags.select{|tag| tag.key == "Name" }.first.value,
          profile: instance.tags.select{|tag| tag.key == "Profile" }.first.value,
          role: instance.tags.select{|tag| tag.key == "Role" }.first.value,
          type: instance.instance_type,
          state: instance.state.name,
          public_ip: instance.public_ip_address,
        }
        instances << instance
      end
    end

    return instances
  end

  private

  # VPC IDを取得します。
  def get_vpc_id
    vpc_id = nil
    resp = @ec2.describe_vpcs({ filters: @profile_filters })
    resp.on_success do
      resp.vpcs.each do |vpc|
        vpc_id = vpc.vpc_id
      end
    end

    return vpc_id
  end

  # ファイアウォールのルールテキストを分解する
  def expand_firewall_rule(rule)
    type, proto, port, src = rule.split("/")

    if type.nil? or proto.nil? or port.nil? or src.nil?
      raise Thor::Error, "rule format error: #{rule}"
    end

    case proto
    when "tcp"
    when "udp"
    when "all"
      proto = "-1"
    else
      raise Thor::Error, ""
    end

    case src
    when "client"
      # このマシンのグローバルIPを調べる
      ip = RestClient.get 'http://checkip.amazonaws.com/'
      cidr = "#{ip.chomp}/32"
    when "all"
      cidr = "0.0.0.0/0"
    else
      cidr = src
    end

    if port == "all"
      from_port = 0
      to_port = 65535
    elsif port =~ /^\d+$/
      from_port = port.to_i
      to_port = port.to_i
    else
      raise Thor::Error, "port required numeric"
    end

    return type, proto, from_port, to_port, cidr
  end

  # 最低限のオプション付きフィルターを取得する
  def get_filter_options(options)
    filters = []
    filters.concat(@profile_filters)

    if options.instance_of?(Array)
      filters.concat(options)
    else
      filters << options
    end
  end

  # 指定したリソースにデフォルトタグを設定します。
  def set_default_tag(type, resource_id)
    resp = @ec2.create_tags({
      resources: [resource_id],
      tags: [
        { key: "Name", value: "#{@profile}-#{type}" },
        { key: "Profile", value: @profile },
      ]
    })

    onerror_response(resp, "create #{type} tag to #{resource_id}")
  end

  # APIレスポンスを検証し、エラー時は例外を投げて強制終了します。
  def onerror_response(resp, message)
    if resp.successful?
      $log.info "#{message} successful"
    else
      raise "#{message} failure: #{resp.error}"
    end
  end
end

