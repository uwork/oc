#-*- encoding: utf-8 -*-


require 'spec_helper'


module FirewallSpec

  describe Firewall do

    before do
      aws_api_mock = double("aws api")
      allow(aws_api_mock).to receive(:delete_security_group)
      allow(aws_api_mock).to receive(:create_security_group)
      allow(AwsApi).to receive(:new).and_return(aws_api_mock)
    end

    it "firewall add" do
      name = "basic-test"

      options = { rule: "in/tcp/3306/client", desc: "test" }

      command = Firewall.new
      command.exec("add", name, "test", options)
    end

    it "firewall remove" do
      name = "basic-test"
      options = { }

      command = Firewall.new
      command.exec("remove", name, "test", options)
    end

  end
end

