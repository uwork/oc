#-*- encoding: utf-8 -*-


require 'spec_helper'

module RemoteSpec
  include AwsConfigData

  describe Remote do

    before do

      # stub の準備
      channel_mock = double("ssh channel")
      allow(channel_mock).to receive(:request_pty)
      allow(channel_mock).to receive(:on_data)
      allow(channel_mock).to receive(:on_extended_data)
      allow(channel_mock).to receive(:send_data) do |data|
        print data
      end
      allow(channel_mock).to receive(:process)
      allow(channel_mock).to receive(:eof?)
      allow(channel_mock).to receive(:eof!)
      allow(channel_mock).to receive(:exec) do |command|
        puts command
      end
      allow(channel_mock).to receive(:send_channel_request) do |shell, &block|
        block.call(channel_mock, true)
      end

      scp_mock = double("scp")
      allow(scp_mock).to receive(:download!) do |remote, local|
        puts "scp #{remote} #{local}"
      end
      allow(Net::SCP).to receive(:download!) do |host, user, remote, local, ssh_option|
        puts "Net::SCP #{user}@#{host}:#{remote} #{local}"
      end

      ssh_mock = double("ssh")
      allow(ssh_mock).to receive(:exec)
      allow(ssh_mock).to receive(:loop)
      allow(ssh_mock).to receive(:open_channel) do |ssh, &block|
        block.call(channel_mock)
      end
      allow(ssh_mock).to receive(:scp).and_return(scp_mock)

      allow(Net::SSH).to receive(:start) do |host, user, keys, &block|
        block.call(ssh_mock)
      end

      allow(Kernel).to receive(:system) do |command|
        puts command
        true
      end
    end

    it "connect to remote" do
      remote = Remote.new("host", "user", "key_path")
      expect {
        remote.connect do |ssh|
          remote.exec "echo hello world"
        end
      }.to output("echo hello world\n").to_stdout
    end

    it "connect to remote" do
      remote = Remote.new("host", "user", "key_path")
      expect {
        remote.exec "echo hello world"
      }.to output("echo hello world\n").to_stdout
    end

    it "get remote file" do
      remote = Remote.new("host", "user", "key_path")
      expect {
        remote.get("test.txt", "/tmp/test.txt")
      }.to output("Net::SCP user@host:test.txt /tmp/test.txt\n").to_stdout
    end

    it "get remote file in connect block" do
      remote = Remote.new("host", "user", "key_path")
      expect {
        remote.connect do |ssh|
          remote.get("test.txt", "/tmp/test.txt")
        end
      }.to output("scp test.txt /tmp/test.txt\n").to_stdout
    end

    it "sync up" do
      remote = Remote.new("host", "user", "key_path")
      expect {
        remote.sync_up("/tmp/local/", "/tmp/remote")
      }.to output("rsync -az -e 'ssh -i key_path' /tmp/local/ user@host:/tmp/remote\n").to_stdout
    end

    it "sync up recursive path" do
      remote = Remote.new("host", "user", "key_path")
      expect {
        remote.sync_up("local/", "/tmp/remote")
      }.to output("rsync -az -e 'ssh -i key_path' #{ENV['CURRENT_DIR']}/local/ user@host:/tmp/remote\n").to_stdout
    end

    it "sync down" do
      remote = Remote.new("host", "user", "key_path")
      expect {
        remote.sync_down("/tmp/remote", "/tmp/local")
      }.to output("rsync -az -e 'ssh -i key_path' user@host:/tmp/remote /tmp/local\n").to_stdout
    end

    it "sync down recursive path" do
      remote = Remote.new("host", "user", "key_path")
      expect {
        remote.sync_down("/tmp/remote", "local")
      }.to output("rsync -az -e 'ssh -i key_path' user@host:/tmp/remote #{ENV['CURRENT_DIR']}/local\n").to_stdout
    end


  end
end

