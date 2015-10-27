#-*- encoding: utf-8 -*-

require 'net/ssh'
require 'net/scp'
require 'stringio'

# リモートホストに接続してコマンドを実行するクラス
class Remote

  # ホストに接続する
  def initialize(host, user, key, output = true)
    @host = host
    @user = user
    @key = key
    @output = output
    @buffer = ""
  end

  def connect
    Net::SSH.start(@host, @user, keys: [@key]) do |ssh|
      @ssh = ssh

      yield ssh

    end


    @ssh = nil
  end


  # コマンドを実行する
  def exec(command)

    if @ssh.nil?

      # セッションが開かれていない場合は、単発で閉じる
      connect do |ssh|
        exec command
      end

    else
      $log.info "REMOTE EXEC: #{command}"

      @ssh.open_channel do |ch|
        ch.request_pty do |ch2, success|
          raise Thor::Error, "request pty error!" if !success
        end

        if @output
          ch.on_data do |chd, data|
            remote_log(data)
          end
        end

        ch.exec command do |ch2, success|
          raise Thor::Error, "open shell failed!" if !success
        end
      end

      @ssh.loop
    end
  end

  # ファイルをダウンロードする
  def get(remote_file, local_path)
    $log.info "download #{remote_file} ----> #{local_path}"
    if @ssh.nil?
      Net::SCP.download!(@host, @user, remote_file, local_path, ssh: { keys: [@key] })
    else
      @ssh.scp.download!(remote_file, local_path)
    end
  end

  # ローカルディレクトリをリモートに同期する
  def sync_up(local_dir, remote_dir)
    if !local_dir.start_with?("/")
      _local_dir = File.expand_path(local_dir, ENV['CURRENT_DIR'])
      _local_dir += "/" if local_dir.end_with?("/")
      local_dir = _local_dir
    end

    rsync(local_dir, "#{@user}@#{@host}:#{remote_dir}")
  end

  # リモートディレクトリをローカルに同期する
  def sync_down(remote_dir, local_dir)
    if !local_dir.start_with?("/")
      _local_dir = File.expand_path(local_dir, ENV['CURRENT_DIR'])
      _local_dir += "/" if local_dir.end_with?("/")
      local_dir = _local_dir
    end

    rsync("#{@user}@#{@host}:#{remote_dir}", local_dir)
  end

  private

  def remote_log(data)
    @buffer += data

    if data.include?("\n")
      # 1行ずつログ出力
      @buffer.each_line do |line|
        $log.info "[%-15s] > %s" % [@host, line.chomp]
      end
      @buffer = ""
    end
  end

  # rsyncを実行する
  def rsync(from, to)

    # 共通のオプションでrsyncを実行
    args = ["rsync"]
    args << "-az" # 圧縮転送、追加・更新のみ。削除はしない。
    args << "-e 'ssh -i #{@key}'" unless @key.nil?
    args << from
    args << to

    command = args.join(" ")
    $log.info command

    if !Kernel.system(command)
      raise Thor::Error, "rsync execution error."
    end
  end
end
