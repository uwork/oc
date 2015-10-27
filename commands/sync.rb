#-*- encoding: utf-8 -*-

class Sync

  def exec(action, local, remote, profile, options)
    @profile = profile
    @api = AwsApi.new(@profile)

    if !local.start_with?("/")
      local = ENV['CURRENT_DIR'] + local
    end

    # ノードを取得
    nodes = @api.find_instances(options[:role])

    # 各ノード毎にスレッドを起動して実行する
    threads = nodes.map.with_index do |node_, idx|
      Thread.start(node_, idx.to_s) do |node, index|

        case action
        when "up"
          sync_up(node, local, remote, options)
        when "down"
          sync_down(node, remote, "#{local}/node-#{node[:public_ip]}", options)
        else
          raise Thor::Error, "action #{action} don't known."
        end
      end
    end

    # 各スレッドが終了するのを待つ
    threads.each{|t| t.join }
  end

  private

  # リモートホストと同期する
  def sync_up(node, local_path, remote_path, options)
    remote = Remote.new(node[:public_ip], "ec2-user", @api.profile_private_key)
    remote.sync_up(local_path, remote_path)
  end

  # リモートホストと同期する
  def sync_down(node, remote_path, local_path, options)
    remote = Remote.new(node[:public_ip], "ec2-user", @api.profile_private_key)
    remote.sync_down(remote_path, local_path)
  end


end

