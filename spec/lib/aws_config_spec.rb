#-*- encoding: utf-8 -*-

require 'spec_helper'

module AwsConfigSpec
  include AwsConfigData

  describe AwsConfig do

    def prepare_credentials
      File.write(AWS_CREDENTIALS_PATH, AWS_CREDENTIALS_CONTENT)
      File.write(AWS_CONFIG_PATH, AWS_CONFIG_CONTNT)
    end

    let(:input) { [ ACCESS_KEY_ID, SECRET_KEY ] }

    it "test credentials save" do
      FileUtils.rm(AWS_CREDENTIALS_PATH)
      FileUtils.rm(AWS_CONFIG_PATH)

      allow(STDIN).to receive(:gets).and_return(*input)
      AwsConfig.setup("test", { region: "us-east-1", output: "json" }, AWS_CREDENTIALS_PATH, AWS_CONFIG_PATH)

      credentials = File.read(AWS_CREDENTIALS_PATH)
      expect(credentials).to eq AWS_CREDENTIALS_CONTENT

      config = File.read(AWS_CONFIG_PATH)
      expect(config).to eq AWS_CONFIG_CONTNT
    end

    it "test credentials load" do
      prepare_credentials

      credentials = AwsConfig.load_credentials("test", AWS_CREDENTIALS_PATH, AWS_CONFIG_PATH)
      expect(credentials[:access_id]).to eq ACCESS_KEY_ID
      expect(credentials[:secret]).to eq SECRET_KEY
      expect(credentials[:region]).to eq "us-east-1"
    end

    it "test profile exists" do
      prepare_credentials

      expect(AwsConfig.profile_exists?("test", AWS_CREDENTIALS_PATH, AWS_CONFIG_PATH)).to eq true
      expect(AwsConfig.profile_exists?("dev", AWS_CREDENTIALS_PATH, AWS_CONFIG_PATH)).to eq false
    end

  end

end
