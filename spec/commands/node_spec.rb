#-*- encoding: utf-8 -*-


require 'spec_helper'


module NodeSpec
  include AwsConfigData

  describe Node do

    let(:answer_yes) { [ "y\n" ] }
    let(:answer_no) { [ "N\n" ] }

    before do
      # stub用データを読み込む
      aws_config_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_config_stub.yml"))
      aws_api_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_api_stub.yml"))

      allow(AwsConfig).to receive(:load_credentials).and_return(aws_config_stub[:basic])

      aws_api_mock = double("aws api")
      @aws_api_mock = aws_api_mock
      allow(aws_api_mock).to receive(:profile_private_key).and_return(AWS_CREDENTIALS_PATH)
      allow(aws_api_mock).to receive(:find_instances).and_return(aws_api_stub[:single][:find_instances])
      allow(aws_api_mock).to receive(:create_instances)
      allow(aws_api_mock).to receive(:start_instances)
      allow(aws_api_mock).to receive(:shutdown_instances)
      allow(AwsApi).to receive(:new).and_return(aws_api_mock)

      provisioner_mock = double("provisioner")
      allow(provisioner_mock).to receive(:sync_local_repo)
      allow(provisioner_mock).to receive(:prepare)
      allow(provisioner_mock).to receive(:provision) do |host, user, type, option, local|
        puts "provision #{user}@#{host} type:#{type}"
      end
      allow(Provisioner).to receive(:new).and_return(provisioner_mock)
    end

    it "nodes list" do
      options = { role: "test" }
      command = Node.new
      expect { command.exec("ls", "test", options) }.to output(<<EOC
+-----------------+-----------------+-----------------+-----------------+-----------------+
| id              | profile         | state           | type            | public_ip       |
+-----------------+-----------------+-----------------+-----------------+-----------------+
| i-111111        | default         | running         | t2.micro        | 10.0.1.1        |
+-----------------+-----------------+-----------------+-----------------+-----------------+
EOC
).to_stdout

    end

    it "all nodes list" do
      aws_api_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_api_stub.yml"))
      allow(@aws_api_mock).to receive(:find_instances).and_return(aws_api_stub[:basic][:find_instances])

      options = {}
      command = Node.new
      expect { command.exec("ls", "test", options) }.to output(<<EOC
+-----------------+-----------------+-----------------+-----------------+-----------------+
| id              | profile         | state           | type            | public_ip       |
+-----------------+-----------------+-----------------+-----------------+-----------------+
| i-111111        | default         | running         | t2.micro        | 10.0.1.1        |
| i-222222        | default         | running         | t2.micro        | 10.0.1.2        |
+-----------------+-----------------+-----------------+-----------------+-----------------+
EOC
).to_stdout
    end

    it "nodes create" do
      options = { role: "test", type: "t2.micro", num: 1 }
      command = Node.new
      command.exec("new", "test", options)
    end

    it "nodes up" do
      options = { role: "test" }
      command = Node.new
      command.exec("up", "test", options)
    end

    it "nodes down" do
      options = { role: "test" }
      command = Node.new
      command.exec("down", "test", options)
    end

    it "nodes shutdown" do
      allow(STDIN).to receive(:gets).and_return(*answer_yes)

      options = { role: "test" }
      command = Node.new
      command.exec("halt", "test", options)
    end

    it "nodes shutdown interrupt" do
      allow(STDIN).to receive(:gets).and_return(*answer_no)

      options = { role: "test" }
      command = Node.new
      expect { command.exec("halt", "test", options) }.to raise_error(Thor::Error, "中断しました")
    end

    it "nodes shutdown noconfirm" do
      options = { role: "test", yes: true }
      command = Node.new
      command.exec("halt", "test", options)
    end

    it "nodes provisioning" do
      options = { role: "test" }

      role_config = YAML.load_file("spec/fixtures/role_config_shell_stub.yml")
      allow(RoleConfig).to receive(:load).and_return(role_config)

      command = Node.new
      expect { command.exec("provision", "test", options) }.to output("provision ec2-user@10.0.1.1 type:shell\n").to_stdout
    end

    it "node ssh" do
      options = { role: "test" }

      allow(Kernel).to receive(:system) do |command|
        puts command
      end

      command = Node.new
      expect { command.exec("ssh", "test", options) }.to output("ssh -i /tmp/.aws_credentials ec2-user@10.0.1.1\n").to_stdout
    end

  end
end

