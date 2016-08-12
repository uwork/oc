#-*- encoding: utf-8 -*-

require 'spec_helper'

module AwsConfigSpec
  include AwsConfigData

  describe AwsApi do

    before do
      File.write(AWS_CREDENTIALS_PATH, AWS_CREDENTIALS_CONTENT)
      File.write(AWS_CONFIG_PATH, AWS_CONFIG_CONTNT)

      # 自身のIPアドレス確認用のHTTPリクエストstubを準備
      allow(RestClient).to receive(:get).and_return("127.0.0.1")

      # stub用のデータを読み込む
      stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_sdk_stub.yml"))
      client = Aws::EC2::Client.new({ stub_responses: stub[:basic] })
      @api = AwsApi.new("test", AWS_CREDENTIALS_PATH, AWS_CONFIG_PATH, client)
    end

    it "credentials profile setup" do
      @api.init_vpc("10.0.0.0/16", [{ name: "public", cidr: "10.0.10.0/24", auto_ip: true }])
    end

    it "create security group test" do
      @api.create_security_group("sample", ["in/tcp/80/client"])
    end

    it "delete vpc test" do
      # 構築済みvpcの状態を再現してテストする
      stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_sdk_stub.yml"))
      client = Aws::EC2::Client.new({ stub_responses: stub[:state_created] })
      api = AwsApi.new("test", AWS_CREDENTIALS_PATH, AWS_CONFIG_PATH, client)
      api.delete_vpc
    end

    it "create instance test" do
      @api.create_instances("t2.micro", "web", 1)
    end

    it "start instance test" do
      @api.start_instances("web")
    end

    it "stop instances test" do
      @api.shutdown_instances("web", false)
    end

    it "stop instances test" do
      @api.shutdown_instances("web", true)
    end

    it "find instances test" do
      @api.find_instances("web")
      @api.find_instances("web", :running)
      @api.find_instances("web", :stopped)
      @api.find_instances("web", :noterminate)
    end

    it "create security group test" do
      @api.create_security_group("basic-test", ["in/all/all/all"], "description")
      @api.create_security_group("basic-test", ["in/tcp/80/all"], "description")
      @api.create_security_group("basic-test", ["in/tcp/3306/client"], "description")
      @api.create_security_group("basic-test", ["in/tcp/3306/internal"], "description")
      @api.create_security_group("basic-test", ["ouot/udp/3309/127.0.0.1"], "description")
    end

    it "delete security group test" do
      @api.delete_security_group("basic-test")
    end

  end

end

