#-*- encoding: utf-8 -*-

require 'spec_helper'


module SyncSpec
  include AwsConfigData

  describe Sync do

    before do
      # stub用データを読み込む
      aws_api_stub = Hashie::Mash.new(YAML.load_file("spec/fixtures/aws_api_stub.yml"))

      # stubを準備
      remote_mock = double("Remote")
      allow(remote_mock).to receive(:sync_up) do |local_path, remote_path|
        puts "rsync #{local_path} #{remote_path}"
      end
      allow(remote_mock).to receive(:sync_down) do |remote_path, local_path|
        puts "rsync #{remote_path} #{local_path}"
      end
      allow(Remote).to receive(:new).and_return(remote_mock)

      aws_api_mock = double("aws api")
      allow(aws_api_mock).to receive(:profile_private_key).and_return(AWS_CREDENTIALS_PATH)
      allow(aws_api_mock).to receive(:find_instances).and_return(aws_api_stub[:single][:find_instances])
      allow(AwsApi).to receive(:new).and_return(aws_api_mock)
    end

    it "sync up" do
      options = { role: "test" }
      local = "/tmp/.synclocal"
      remote = "/tmp/.syncremote"

      command = Sync.new
      expect { command.exec("up", local, remote, "test", options) }.to output("rsync #{local} #{remote}\n").to_stdout
    end

    it "sync up relative path" do
      options = { role: "test" }
      local = ".synclocal"
      remote = "/tmp/.syncremote"

      command = Sync.new
      expect { command.exec("up", local, remote, "test", options) }.to output("rsync #{ENV['CURRENT_DIR'] + local} #{remote}\n").to_stdout
    end

    it "sync down" do
      options = { role: "test" }
      local = "/tmp/.synclocal"
      remote = "/tmp/.syncremote"

      command = Sync.new
      expect { command.exec("down", local, remote, "test", options) }.to output("rsync #{remote} #{local}/node-10.0.1.1\n").to_stdout
    end

  end
end

