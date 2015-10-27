#-*- encoding: utf-8 -*-

class Provisioner

  # リポジトリのテンポラリディレクトリ
  TEMP_OC_DIR = "/tmp/.oc"
  TEMP_REPO_DIR = "#{TEMP_OC_DIR}/repo"
  TEMP_KEYS_DIR = "#{TEMP_OC_DIR}/keys"
  TEMP_SCRIPTS_DIR = "#{TEMP_OC_DIR}/scripts"

  # 基本設定を渡す
  def initialize(profile, repo, sshkey)
    @profile = profile
    @repo = repo
    @sshkey = sshkey
    @aws_api = AwsApi.new(@profile)
  end

  # テンポラリのリポジトリパスを返す
  def temp_repo_path
    repo_name = @repo.split("/").last.split(":").last.gsub(/\.git$/, "")
    return "#{TEMP_REPO_DIR}/#{repo_name}"
  end

  # ローカルにリポジトリを同期する
  def sync_local_repo
    FileUtils.mkdir_p(TEMP_REPO_DIR) unless File.exists?(TEMP_REPO_DIR)

    # リポジトリ名を抽出する
    local_repo = temp_repo_path

    # ローカルに一度clone|pullする
    if File.exists?(local_repo)
      clone_command = "cd #{local_repo}; git pull"
    else
      clone_command = "git clone #{@repo} #{local_repo}"
    end

    if !Kernel.system(clone_command)
      raise Thor::Error, "git clone failed: #{clone_command}"
    end
  end

  # プロビジョニングの準備を実行する
  def prepare(host, user, type)
    key = @aws_api.profile_private_key
    remote = Remote.new(host, user, key) 

    remote.connect do |ssh|
      remote.exec("mkdir -p #{TEMP_OC_DIR}")
      remote.exec("mkdir -p #{TEMP_KEYS_DIR}")
      remote.exec("mkdir -p #{TEMP_SCRIPTS_DIR}")

      # 初期化スクリプトをアップロード
      remote.sync_up("#{ENV['OC_HOME']}/scripts/", TEMP_SCRIPTS_DIR)

      # 初期化スクリプトを実行
      remote.exec("#{TEMP_SCRIPTS_DIR}/setup_#{type}.sh")
    end
  end

  # プロビジョニングを実行する
  def provision(host, user, type, option, proxy_local)
    key = @aws_api.profile_private_key
    remote = Remote.new(host, user, key) 

    remote.connect do |ssh|
      if proxy_local
        # ローカルからリモートに同期する
        remote.exec("mkdir -p #{TEMP_REPO_DIR}")
        remote.sync_up(temp_repo_path + "/", TEMP_REPO_DIR)
      else
        unless key.nil?
          unless File.exists?(@sshkey)
            raise Thor::Error, "#{@sshkey} not found."
          end
          # 鍵が指定された場合、アップロードしてgit-sshスクリプト経由でgit cloneする
          remote.sync_up(@sshkey, "#{TEMP_KEYS_DIR}/id.pem")

          # リモートで直接git cloneする
          remote.exec("GIT_SSH=#{TEMP_SCRIPTS_DIR}/git-ssh.sh git clone #{@repo} #{TEMP_REPO_DIR}")
        else
          # 鍵なしでgit cloneする
          remote.exec("git clone #{@repo} #{TEMP_REPO_DIR}")
        end

      end

      # プロビジョニングコマンドの準備
      command = case type
                when "chefsolo"; "sudo chef-solo #{option}"
                when "chefzero"; "sudo chef-client -z #{option}"
                when "ansible"; "ansible-playbook -i #{TEMP_SCRIPTS_DIR}/ansible_hosts -s --connection=local #{option}"
                when "shell"; option
                end

      remote.exec("cd #{TEMP_REPO_DIR}; #{command}")
    end
  end


end
