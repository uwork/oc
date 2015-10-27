#-*- encoding: utf-8 -*-


require 'spec_helper'

module RoleConfigSpec

  describe RoleConfig do

    before do
      allow(RoleConfig).to receive(:role_dir).and_return("spec/fixtures")
    end

    it "load from yaml" do
      role_config = RoleConfig.load("role_config_shell_stub")
      expect(role_config["role"]).to eq "test"
      expect(role_config["firewall"]).to eq ["test-onlyme"]
      expect(role_config["provision"]).to eq({
        "repo" => "git@localhost:example/test.git",
        "key" => "/tmp/.oc/keys/key",
        "type" => "shell",
        "option" => "yum -y install httpd",
      })
    end

  end
end

