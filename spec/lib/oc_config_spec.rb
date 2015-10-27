#-*- encoding: utf-8 -*-


require 'spec_helper'

module OcConfigSpec
  include OcConfigData

  describe OcConfig do

    it "type is 'aws'" do
      OcConfig.init("spec/lib/oc_config")
      expect(OcConfig.type).to eq "aws"
    end

    it "profile is 'test'" do
      OcConfig.init("spec/lib/oc_config")
      expect(OcConfig.profile).to eq "test"
    end

    it "test config save" do
      FileUtils.rm(CONFIG_PATH) if File.exists?(CONFIG_PATH)
      OcConfig.setup("aws", { profile: "test" }, CONFIG_PATH)
      config_content = File.read(CONFIG_PATH)
      expect(config_content).to eq CONFIG_CONTENT
    end
  end
end

