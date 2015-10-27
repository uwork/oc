#-*- encoding: utf-8 -*-


require 'spec_helper'


module SetupSpec

  describe Setup do

    before do
      # stub準備
      allow(AwsConfig).to receive(:setup)
      allow(OcConfig).to receive(:setup)
    end

    it "setup option test" do
      options = { profile: "test" }

      command = Setup.new
      command.exec("aws", options)
    end

    it "setup error test" do
      options = { profile: "test" }

      command = Setup.new
      expect { command.exec("gcp", options) }.to raise_error(Thor::Error, "不明なtype: gcp")
    end

  end
end

