#-*- encoding: utf-8 -*-

require 'aws-sdk'
require 'inifile'

class AwsConfig

  CONFIG_PATH = "#{ENV['HOME']}/.aws/config"
  CREDENTIALS_PATH = "#{ENV['HOME']}/.aws/credentials"

  class << self

    def setup(profile, opts, credentials_path = CREDENTIALS_PATH, config_path = CONFIG_PATH)

      if profile_exists?(profile, credentials_path, config_path)
        load_credentials(profile, credentials_path, config_path)
      end

      puts "setup aws credentials [#{profile}]"
      puts "  profile: #{profile}"
      puts "  region: #{opts[:region]}"

      printf "  aws access id: "
      access_id = STDIN.gets.chomp

      printf "  aws access secret: "
      secret = STDIN.gets.chomp

      # directory force create.
      dir = File.dirname(credentials_path)
      FileUtils.mkdir_p(dir) unless File.exists?(dir)

      save_credentials(profile, access_id, secret, credentials_path)
      save_config(profile, opts, config_path)
      load_credentials(profile, credentials_path, config_path)

    end

    def profile_exists?(profile, credentials_path = CREDENTIALS_PATH, config_path = CONFIG_PATH)
      if !File.exists?(credentials_path) or !File.exists?(config_path)
        return false
      end

      credentials = IniFile.load(credentials_path, encoding: "utf-8")
      config = IniFile.load(config_path, encoding: "utf-8")
      if config[profile].empty? or credentials[profile].empty?
        return false
      else
        return true
      end
    end

    def load_credentials(profile, credentials_path = CREDENTIALS_PATH, config_path = CONFIG_PATH)
      credentials = IniFile.load(credentials_path, encoding: "utf-8")
      if credentials[profile].empty?
        raise Thor::Error, "プロファイルが存在しません #{profile}"
      end

      access_id = credentials[profile]["aws_access_key_id"]
      secret = credentials[profile]["aws_secret_access_key"]

      config = IniFile.load(config_path, encoding: "utf-8")
      region = config[profile]["region"]

      Aws.config.update(
        region: region
      )

      return {
        access_id: access_id,
        secret: secret,
        region: region
      }
    end

    private # ----- 以下private メソッド

    def save_credentials(profile, access_id, secret, credentials_path = CREDENTIALS_PATH)
      if File.exists?(credentials_path)
        credentials = IniFile.load(credentials_path)
      else
        credentials = IniFile.new
      end
      credentials[profile]["aws_access_key_id"] = access_id
      credentials[profile]["aws_secret_access_key"] = secret
      credentials.write(filename: credentials_path, encoding: "utf-8")

      $log.info "aws credentials saved: #{credentials_path}"
    end

    def save_config(profile, opts, config_path = CONFIG_PATH)
      if File.exists?(config_path)
        config = IniFile.load(config_path)
      else
        config = IniFile.new
      end

      config[profile]["region"] = opts[:region]
      config[profile]["output"] = opts[:output]
      config.write(filename: config_path, encoding: "utf-8")

      $log.info "aws config saved: #{config_path}"
    end

  end


end
