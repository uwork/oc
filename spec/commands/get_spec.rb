#-*- encoding: utf-8 -*-

require 'spec_helper'


module GetSpec
  include AwsConfigData

  describe Get do

    before do
      # stub用データを読み込む
      aws_config_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_config_stub.yml"))
      aws_api_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_api_stub.yml"))

      # stubを準備
      remote_mock = double("Remote")
      allow(remote_mock).to receive(:get) do |remote_path, local_path|
        puts "scp #{remote_path} #{local_path}"
      end
      allow(Remote).to receive(:new).and_return(remote_mock)
      allow(AwsConfig).to receive(:load_credentials).and_return(aws_config_stub[:basic])

      aws_api_mock = double("aws api")
      allow(aws_api_mock).to receive(:profile_private_key).and_return(AWS_CREDENTIALS_PATH)
      allow(aws_api_mock).to receive(:find_instances).and_return(aws_api_stub[:single][:find_instances])
      allow(AwsApi).to receive(:new).and_return(aws_api_mock)

      allow(FileUtils).to receive(:mkdir_p)
    end

    it "get test" do
      options = { role: "test" }
      command = Get.new
      expect { command.exec("file", "test", options) }.to output("scp #{Cmd::WORK_DIR}/file #{ENV['OC_HOME']}/node-10.0.1.1\n").to_stdout
    end


  end
end

