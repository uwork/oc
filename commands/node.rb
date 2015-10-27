 #-*- encoding: utf-8 -*-
  
require 'parallel'

class Node

  def exec(action, profile, options)
    @api = AwsApi.new(profile)

    case action
    when "ls"
      list(profile, options)
    when "new"
      new(profile, options)
    when "up"
      up(profile, options)
    when "down"
      down(profile, options)
    when "halt"
      halt(profile, options)
    when "provision"
      provision(profile, options)
    when "ssh"
      ssh(profile, options)
    else
      raise Thor::Error, "不明なaction: #{action}"
    end
  end

  # ノードリストを表示する
  def list(profile, options)
    role = options[:role]

    instances = @api.find_instances(role, :all)

    print_items = [:id, :profile, :state, :type, :public_ip]
    line_format = "| %s |\n" % print_items.map{|i| "%-15s"}.join(" | ")
    border = "+%s+\n" % print_items.map{ 17.times.map{"-"}.join }.join("+")

    puts border
    puts line_format % print_items
    puts border
    instances.each do |node|
      puts line_format % print_items.map{|i| node[i]}
    end
    puts border
  end


  # 新規ノードを起動する
  def new(profile, options)
    $log.info "launch nodes..."

    type = options[:type]
    num = options[:num]
    role = options[:role]

    if type.nil?
      raise Thor::Error, "--type=TYPE is required."
    elsif num.nil?
      raise Thor::Error, "--num=NUM is required."
    elsif role.nil?
      raise Thor::Error, "--role=ROLE is required."
    end

    @api.create_instances(type, role, num)
  end

  # 停止中のノードを起動する
  def up(profile, options)
    role = options[:role]

    $log.info "start nodes..."

    @api.start_instances(role)
  end

  # 起動中のノードを停止する
  def down(profile, options)
    role = options[:role]

    $log.info "stop nodes..."

    @api.shutdown_instances(role, false)
  end

  # ノードを削除する
  def halt(profile, options)
    $log.info "shutdown nodes..."

    role = options[:role]
    yes = options[:yes]

    instances = @api.find_instances(role, :noterminate)
    if instances.empty?
      raise Thor::Error, "対象のインスタンスがありませんでした"
    end

    ids = instances.map{|i| i[:id] }
    $log.info "trying shutdown instances: #{ids}"
    unless yes
      while true do
        print "本当に terminate しますか？[y/N]"
        ans = STDIN.gets.chomp
        if ans.downcase == "y" or ans.downcase == "yes"
          break
        elsif ans == "" or ans.downcase == "n" or ans.downcase == "no"
          raise Thor::Error, "中断しました"
        end
      end
    end

    @api.shutdown_instances(role, true)
  end

  # ノードをプロビジョニングする
  def provision(profile, options)
    # ロール設定を読み込む
    role = options[:role]
    if role.nil?
      raise Thor::Error, "--ROLE is required."
    end

    role_config = RoleConfig.load(role)

    if !role_config["provision"]
      raise Thor::Error, "provision config not found: #{role}"
    end

    # プロビジョニングを実行する
    prov_config = role_config["provision"]
    type, repo, key, option, local = prov_config["type"], prov_config["repo"], prov_config["key"], prov_config["option"], prov_config["local"]

    $log.info "type: #{type}"
    $log.info "repo: #{repo}"
    $log.info "key: #{key}"
    $log.info "option: #{option}"
    $log.info "local: #{local}"

    nodes = @api.find_instances(role)

    $log.info "provisioning nodes: #{nodes.map{|i|i[:id]}}"

    # ノード毎にスレッドを起動して実行する。スレッド数はとりあえず4。
    provisioner = Provisioner.new(profile, repo, key)

    if local
      # ローカルを経由してリポジトリを送り込む
      provisioner.sync_local_repo
    end

    Parallel.each(nodes, in_threads: 4) do |node|
      $log.info "start provision node: #{node[:public_ip]}"

      provisioner.prepare(node[:public_ip], "ec2-user", type)
      provisioner.provision(node[:public_ip], "ec2-user", type, option, local)
    end
  end

  # ノードにSSHする
  def ssh(profile, options)
    id = options[:id]
   
    role = options[:role]
    instances = @api.find_instances(role)

    if id.nil?
      if instances.empty?
        raise Thor::Error, "instances not found."
      elsif 1 < instances.size
        raise Thor::Error, "インスタンスが複数存在するため、 --id を指定してインスタンスを指定してください。"
      else
        node = instances.first
      end
    else
      node = instances.select{|i| i[:id] == id}.first
      if node.nil?
        raise Thor::Error, "instance #{id} not found."
      end
    end

    # ssh コマンドを実行する
    Kernel.system("ssh -i #{@api.profile_private_key} ec2-user@#{node[:public_ip]}")
  end
end

