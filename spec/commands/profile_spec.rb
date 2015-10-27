#-*- encoding: utf-8 -*-


require 'spec_helper'


module ProfileSpec

  describe Profile do

    before do
      aws_api_mock = double("aws api")
      allow(aws_api_mock).to receive(:init_vpc)
      allow(aws_api_mock).to receive(:delete_vpc)
      allow(AwsApi).to receive(:new).and_return(aws_api_mock)
    end

    it "profile option validation" do
      options = { role: "test", cidr: "10.1.0.0/16", subnets: "public/10.1.2.0/24/true" }

      command = Profile.new
      cidr, subnets = command.extract_options(options)
      expect(cidr).to eq("10.1.0.0/16")
      expect(subnets).to eq([
        { name: "public", cidr: "10.1.2.0/24", auto_ip: true }
      ])
    end

    it "profile prepare" do
      options = { role: "test", cidr: "10.0.0.0/16", subnets: "public/10.0.0.0/24/true" }

      command = Profile.new
      command.exec("prepare", "test", options)
    end

    it "profile clean" do
      options = { role: "test" }

      command = Profile.new
      command.exec("clean", "test", options)
    end

  end
end

