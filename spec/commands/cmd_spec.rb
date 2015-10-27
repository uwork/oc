#-*- encoding: utf-8 -*-


require 'spec_helper'


module CmdSpec
  include AwsConfigData

  describe Cmd do

    before do
      # stub用データを読み込む
      aws_config_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_config_stub.yml"))
      aws_api_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_api_stub.yml"))

      # stubを準備
      remote_mock = double("Remote")
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
      allow(AwsConfig).to receive(:load_credentials).and_return(aws_config_stub[:basic])

      aws_api_mock = double("aws api")
      allow(aws_api_mock).to receive(:profile_private_key).and_return(AWS_CREDENTIALS_PATH)
      allow(aws_api_mock).to receive(:find_instances).and_return(aws_api_stub[:single][:find_instances])
      allow(AwsApi).to receive(:new).and_return(aws_api_mock)
    end

    it "basic exec test" do
      options = {}
      command = Cmd.new
      expect { command.exec("ls", "test", options) }.to output(<<EOC).to_stdout
mkdir -p #{Cmd::WORK_DIR}
cd #{Cmd::WORK_DIR}; ls
EOC
    end

    it "dir option test" do
      sync_dir = "/tmp/.oc/syncdir/"
      FileUtils.mkdir_p(sync_dir)

      options = { dir: sync_dir }
      command = Cmd.new
      expect { command.exec("ls", "test", options) }.to output(<<EOC
rsync #{sync_dir} #{Cmd::WORK_DIR}
cd #{Cmd::WORK_DIR}; ls
EOC
        ).to_stdout
    end

  end
end

