#-*- encoding: utf-8 -*-


class RoleConfig

  ROLE_DIR = "#{ENV['OC_HOME']}/share/roles"
  ETC_DIR = "/etc/oc.roles.d"

  def self.role_dir
    ROLE_DIR
  end

  def self.etc_dir 
    ETC_DIR
  end

  # ロール設定を読み込む
  def self.load(role)

    role_file = "#{self.role_dir}/#{role}.yml"
    etc_role_file = "#{self.etc_dir}/#{role}.yml"

    if File.exists?(etc_role_file) # etc ファイルを確認
      config = YAML.load_file(etc_role_file)
    elsif File.exists?(role_file) # share/roles ファイルを確認
      config = YAML.load_file(role_file)
    else
      raise Thor::Error, "role_file: #{role_file} not found."
    end

    # aws用のdevice mappingオプションを準備
    if config['devices']
      config['devices_mapping'] = config['devices'].map do |device, ebs|
        {
          device_name: device,
          ebs: {
            volume_size: ebs["size"],
            delete_on_termination: ebs["ondelete"],
            volume_type: ebs["type"],
          }
        }
      end
    end

    # ロール設定の上位を読み込む
    if config["parent"]
      parent_config = self.load(config["parent"])
      config = parent_config.merge(config)
    end

    return config
  end

end
