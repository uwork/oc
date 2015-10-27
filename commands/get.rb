#-*- encoding: utf-8 -*-

class Get

  def exec(path, profile, options)
    @profile = profile

    # ノードを取得
    nodes = describe_nodes(options)

    # 各ノード毎にスレッドを起動して実行する
    threads = nodes.map.with_index do |node_, idx|
      Thread.start(node_, idx.to_s) do |node, index|
        download(node, path)
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


  # ファイルをダウンロードする
  def download(node, path)
    local_path = "#{ENV['CURRENT_DIR']}/node-#{node[:public_ip]}"
    FileUtils.mkdir_p(local_path) unless File.exists?(local_path)

    path = File.expand_path(path, Cmd::WORK_DIR)

    api = AwsApi.new(@profile)
    remote = Remote.new(node[:public_ip], "ec2-user", api.profile_private_key)
    remote.get(path, local_path)
  end

end
