#-*- encoding: utf-8 -*-
require 'thor'
require 'logger'

Dir['./commands/*.rb', './lib/*.rb'].each do |file|
  require './' + file
end

# global Logger
$log = Logger.new(STDOUT)
$log.formatter = proc{|severity, datetime, progname, message|
  "#{severity}: #{message}\n"
}
#$log = Logger.new('logs/oc.log')

# initialize configuration.
OcConfig.init

# Oreore Command.
class OC < Thor

  desc "setup TYPE", "TYPE{aws}別にocの初期設定を行う(アクセスキーの設定など)"
  method_option :profile, type: "string", default: "default", aliases: "-p", desc: "初期化するプロファイル"
  method_option :region, type: "string", default: "us-east-1", aliases: "-r", desc: "apiを利用するリージョン(aws)"
  method_option :output, type: "string", default: "json", aliases: "-o", desc: "aws apiの出力フォーマット(aws)"
  def setup(type)
    command = Setup.new 
    command.exec(type, options)
  end


  desc "profile ACTION", "ACTION{prepare|firewall|clean}別にプロファイルを操作する"
  method_option :profile, type: :string, default: OcConfig.profile, aliases: "-p", desc: "操作するプロファイル"
  method_option :cidr, type: :string, default: "10.0.0.0/16", desc: "VPCのCIDR(aws)\n\texample: '10.0.0.0/16'"
  method_option :subnets, type: :string, default: "public-subnet/10.0.1.0/24/true,private-subnet/10.0.2.0/24/false", desc: "VPCのSubnet(aws)\n\tformat: ':name/:subnet/:mask/:auto_ip,...'\n\texample: 'public-subnet/10.0.1.0/24/true,private-subnet/10.0.2.0/24/false'"
  def profile(action)
    command = Profile.new
    command.exec(action, options[:profile], options)
  end

  desc "firewall ACTION NAME", "ファイアウォールについてACTION{add|remove}する"
  method_option :profile, type: :string, default: OcConfig.profile, aliases: "-p", desc: "操作するプロファイル"
  method_option :rule, type: :string, aliases: "-r", desc: "追加する場合のファイアウォールのルール\n\tformat: '[in/out]/[tcp/udp/-1]/[port/-1]/[ip_address/all/client]'\n\texample: in/tcp/3306/client"
  method_option :desc, type: :string, aliases: "-d", desc: "追加する場合のファイアウォールの説明文"
  def firewall(action, name)
    command = Firewall.new
    command.exec(action, name, options[:profile], options)
  end

  desc "node ACTION", "ノードを操作する"
  method_option :profile, type: :string, default: OcConfig.profile, aliases: "-p", desc: "ノードを作成するプロファイル"
  method_option :num, type: :numeric, default: 1, aliases: "-n", desc: "起動するノードの数"
  method_option :type, type: :string, aliases: "-t", desc: "起動するインスタンスタイプ"
  method_option :role, type: :string, aliases: "-r", desc: "ノードのロール"
  method_option :yes, type: :boolean, default: false, aliases: "-y", desc: "haltする際、確認せずterminateする"
  method_option :id, type: :string, aliases: "-i", desc: "sshの場合必須。sshするインスタンスidを指定する"
  def node(action)
    command = Node.new
    command.exec(action, options[:profile], options)
  end

  desc "cmd COMMAND", "各ノードでコマンドを実行する"
  method_option :profile, type: :string, default: OcConfig.profile, desc: "コマンドを実行するプロファイル"
  method_option :role, type: :string, desc: "ノードのロール"
  method_option :dir, type: :string, desc: "ノードと同期するローカルディレクトリ"
  def cmd(*cmds)
    command = Cmd.new
    command.exec(cmds.join(" "), options[:profile], options)
  end

  desc "sync up|down LOCAL_PATH REMOTE_PATH", "各ノードとファイルを同期する"
  method_option :profile, type: :string, default: OcConfig.profile, aliases: "-p", desc: "コマンドを実行するプロファイル"
  method_option :role, type: :string, aliases: "-r", desc: "ノードのロール"
  def sync(action, local, remote)
    command = Sync.new
    command.exec(action, local, remote, options[:profile], options)
  end

  desc "get remote_file_path", "各ノードからファイルを取得する"
  method_option :profile, type: :string, default: OcConfig.profile, aliases: "-p", desc: "コマンドを実行するプロファイル"
  method_option :role, type: :string, aliases: "-r", desc: "ノードのロール"
  def get(path)
    command = Get.new
    command.exec(path, options[:profile], options)
  end
end

# execute.
OC.start(ARGV)

