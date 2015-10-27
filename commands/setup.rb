#-*- encoding: utf-8 -*-

class Setup

  def exec(type, opts)
    case type
    when "aws" then
      AwsConfig.setup(opts[:profile], opts)
    else
      raise Thor::Error, "不明なtype: #{type}"
    end

    OcConfig.setup(type, opts)
  end

end

