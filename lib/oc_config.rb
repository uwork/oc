#-*- encoding: utf-8 -*-

require 'inifile'

class OcConfig

  CONFIG_PATH = "#{ENV['HOME']}/.oc/config"

  def self.init(path = CONFIG_PATH)
    if File.exists?(path)
      config = IniFile.load(path, encondig: "utf-8")
      @@type = config["oc"]["type"]
      @@profile = config["oc"]["profile"]
    else
      @@type = nil
      @@profile = nil
    end
  end

  def self.type
    @@type
  end

  def self.profile
    @@profile
  end

  def self.setup(type, opts, path = CONFIG_PATH)
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir) unless File.exists?(dir)

    if File.exists?(path)
      config = IniFile.load(path, encoding: "utf-8")
    else
      config = IniFile.new
    end

    config["oc"]["type"] = type
    config["oc"]["profile"] = opts[:profile]
    config.write(filename: path, encoding: "utf-8")

    $log.info "oc config saved: #{path}"
  end
end
