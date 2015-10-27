#-*- encoding: utf-8 -*-

# プロファイルを操作するコマンド
class Profile

  def exec(action, profile, options)
    @action = action

    case action
    when "prepare"
      prepare(profile, options)
    when "firewall"
      firewall(profile, options)
    when "clean"
      clean(profile, options)
    else
      raise Thor::Error, "不明なaction: #{action}"
    end

  end

  def extract_options(options)
    if !options[:cidr]
      raise Thor::Error, "cidrが指定されていません"
    end
    if !options[:subnets]
      raise Thor::Error, "subnetsが指定されていません"
    end

    cidr = options[:cidr]
    subnets = options[:subnets].split(",").map do |subnet|
      name, subnet, mask, autoip = subnet.split("/")
      { name: name, cidr: "#{subnet}/#{mask}", auto_ip: autoip == "true" }
    end

    return cidr, subnets
  end

  def prepare(profile, options)
    $log.info "prepare profile"

    cidr, subnets = extract_options(options)

    api = AwsApi.new(profile)
    api.init_vpc(cidr, subnets)
  end

  def clean(profile, options)
    $log.info "clean profile"
    
    api = AwsApi.new(profile)
    api.delete_vpc
  end
end
