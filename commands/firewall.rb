#-*- encoding: utf-8 -*-

# ファイアウォールを操作するコマンド
class Firewall

  def exec(action, name, profile, options)
    @action = action

    case action
    when "add"
      add(name, profile, options)
    when "remove"
      remove(name, profile, options)
    else
      raise Thor::Error, "不明なaction: #{action}"
    end

  end

  # ファイアウォールを追加する
  def add(name, profile, options)
    # パラメータチェック
    if !options[:rule]
      raise Thor::Error, "--rules=RULE は必須です"
    end

    aws_api = AwsApi.new(profile)
    aws_api.create_security_group(name, [options[:rule]], options[:desc])
  end

  # ファイアウォールを削除する
  def remove(name, profile, options)
    aws_api = AwsApi.new(profile)
    aws_api.delete_security_group(name)   
  end

end




