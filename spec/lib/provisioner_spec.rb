#-*- encoding: utf-8 -*-


require 'spec_helper'

module ProvisionerSpec
  include AwsConfigData

  describe Provisioner do

    let(:test_key_path) { "/tmp/.oc/keys/testkey.pem" }

    before do
      # テスト鍵の作成
      FileUtils.mkdir_p(File.dirname(test_key_path))
      File.write(test_key_path, "")

      # stub の準備
      remote_mock = double("remote")
      allow(remote_mock).to receive(:connect) do |remote, &block|
        block.call
      end
      allow(remote_mock).to receive(:exec) do |command|
        puts command
      end
      allow(remote_mock).to receive(:sync_up) do |from, to|
        puts "rsync #{from} #{to}"
      end
      allow(Remote).to receive(:new).and_return(remote_mock)

      aws_api_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_api_stub.yml"))
      aws_api_mock = double("aws api")
      allow(aws_api_mock).to receive(:profile_private_key).and_return(AWS_CREDENTIALS_PATH)
      allow(aws_api_mock).to receive(:find_instances).and_return(aws_api_stub[:single][:find_instances])
      allow(AwsApi).to receive(:new).and_return(aws_api_mock)

      allow(Kernel).to receive(:system) do |command|
        puts command
        true
      end
    end

    it "prepare shell" do
      provisioner = Provisioner.new("test", "git@localhost:example/test.git", test_key_path)
      expect { provisioner.prepare("localhost", "ec2-user", "shell") }.to output(<<EOC
mkdir -p #{Provisioner::TEMP_OC_DIR}
mkdir -p #{Provisioner::TEMP_KEYS_DIR}
mkdir -p #{Provisioner::TEMP_SCRIPTS_DIR}
rsync #{ENV['OC_HOME']}/scripts/ #{Provisioner::TEMP_SCRIPTS_DIR}
#{Provisioner::TEMP_SCRIPTS_DIR}/setup_shell.sh
EOC
        ).to_stdout
    end

    it "create temporary path" do
      provisioner = Provisioner.new("test", "git@localhost:example/test.git", test_key_path)
      expect(provisioner.temp_repo_path).to eq("#{Provisioner::TEMP_REPO_DIR}/test")
    end

    it "sync local repo" do
      provisioner = Provisioner.new("test", "git@localhost:example/test.git", test_key_path)
      expect { provisioner.sync_local_repo }.to output(<<EOC
git clone git@localhost:example/test.git #{Provisioner::TEMP_REPO_DIR}/test
EOC
        ).to_stdout
    end

    it "provision shell" do
      option = "yum -y install httpd"

      provisioner = Provisioner.new("test", "git@localhost:example/test.git", test_key_path)
      expect { provisioner.provision("localhost", "ec2-user", "shell", option, false) }.to output(<<EOC
rsync #{test_key_path} #{Provisioner::TEMP_KEYS_DIR}/id.pem
GIT_SSH=#{Provisioner::TEMP_SCRIPTS_DIR}/git-ssh.sh git clone git@localhost:example/test.git #{Provisioner::TEMP_REPO_DIR}
cd #{Provisioner::TEMP_REPO_DIR}; #{option}
EOC
        ).to_stdout
    end

    it "provision proxy local" do
      option = "yum -y install httpd"

      provisioner = Provisioner.new("test", "git@localhost:example/test.git", test_key_path)
      expect { provisioner.provision("localhost", "ec2-user", "shell", option, true) }.to output(<<EOC
mkdir -p #{Provisioner::TEMP_REPO_DIR}
rsync #{Provisioner::TEMP_REPO_DIR}/test/ #{Provisioner::TEMP_REPO_DIR}
cd #{Provisioner::TEMP_REPO_DIR}; #{option}
EOC
        ).to_stdout

    end
  end
end

