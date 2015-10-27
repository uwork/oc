#-*- encoding: utf-8 -*-

# 各ノードでコマンドを実行するコマンド
class Cmd

  WORK_DIR = "/tmp/.ocwork"

  def exec(command, profile, options)
    @profile = profile
    validation_options(options)

    $log.info "multi exec '#{command}' #{options}"

    # ノードを取得
    nodes = describe_nodes(options)

    # 各ノード毎にスレッドを起動して実行する
    threads = nodes.map.with_index do |node_, idx|
      Thread.start(node_, idx.to_s) do |node, index|
        command_ = command.gsub("#index#", index.to_s).gsub("#nodes#", nodes.size.to_s)
        exe_remote(node, command_, options)
      end
    end

    # 各スレッドが終了するのを待つ
    threads.each{|t| t.join }
  end

  private

  # ノードを探す
  def describe_nodes(options)
    api = AwsApi.new(@profile)
    api.find_instances(options[:role])
  end

  # オプションを検証する
  def validation_options(options)
    if options[:dir]
      dir = options[:dir]
      raise Thor::Error, "dir=#{dir} is not directory" if File::ftype(dir) != "directory"
    end
  end

  # コマンドを実行する
  def exe_remote(node, command, options)

    api = AwsApi.new(@profile)
    remote = Remote.new(node[:public_ip], "ec2-user", api.profile_private_key)

    remote.connect do |ssh|
      # dirオプションが指定された場合、そのディレクトリを同期する
      if options[:dir]
        dir = options[:dir]
        dir = File.expand_path(dir, ENV['CURRENT_DIR'])
        remote.sync_up(dir + "/", WORK_DIR)
      else
        remote.exec("mkdir -p #{WORK_DIR}")
      end

      remote.exec("cd #{WORK_DIR}; #{command}")
    end
  end

end
