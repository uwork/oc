
# これは何？

On-demand Cloud command、名付けてocです。  
その場限りでクラウドインスタンスを起動して、各インスタンスにコマンドを分散実行させる事を目的としたユーティリティコマンドです。




# インストール

ruby 1.9.3以上をインストールしておいてください。  
git cloneの後は、bundleし、PATHを設定します。

```bash
$ git clone git@github.com:uwork/oc.git ~/.occmd

$ bundle install

$ echo 'export PATH=$PATH:~/.occmd/bin' >> ~/.bash_profile

$ source ~/.bash_profile
```



# チュートリアル

基本的な使い方から紹介します。  
AWSのアクセスキーは、EC2およびVPCを操作できるユーザーを用意してください。  
**また、色々自動で作ったり消したりするので、できればまっさらなAWSアカウントで使って頂くのが良いかと思います。**

```bash
# 1. ocを初期化します ( ~/.aws/credentials 等を作成しているだけです。)
$ oc setup aws
setup aws credentials [default]
  profile: default
  region: us-east-1
  aws access id: xxxxxxxxxxxxx <-- AWSのアクセスキーを入力します
  aws access secret: xxxxxxxxxxxxx <-- AWSのアクセスシークレットを入力します
INFO: aws credentials saved: /home/user/.aws/credentials
INFO: aws config saved: /home/user/.aws/config
INFO: oc config saved: /home/user/.oc/config

# 2. ocで利用するVPCを初期化します
$ oc profile prepare

# 3. インスタンスを起動します。(t2.microを3台)
# なおデフォルトでは、ocを実行するマシンのグローバルIPのみ接続可能なセキュリティグループを付与します。
$ oc node new -r default -t t2.micro -n 3

# 4. 各ノードでコマンドを実行します。
$ oc cmd "echo helloworld!"

...
INFO: [xxx.xxx.xxx.xxx] > helloworld! 
INFO: [xxx.xxx.xxx.xxx] > helloworld!
INFO: [xxx.xxx.xxx.xxx] > helloworld!
...

# 5. すべてのインスタンスをterminateします。
$ oc node halt -y

# 6. 先ほど作成したVPCを削除します。
$ oc profile clean
```



# 用語

いくつか独自の用語があるのでここで説明します。

|用語|説明|
|---|---|
|プロファイル|ocでの環境単位。プロファイル毎にアクセスキーを保存したり、タグをつけてリソースを管理する|
|ロール|インスタンスの用途を表すロール。プロビジョニングの内容を定義する種別にもなる|



# コマンドのヘルプ

```bash
$ oc help
Commands:
  oc.rb cmd COMMAND                          # 各ノードでコマンドを実行する
  oc.rb firewall ACTION NAME                 # ファイアウォールについてACTION{add|remove}する
  oc.rb get remote_file_path                 # 各ノードからファイルを取得する
  oc.rb help [COMMAND]                       # Describe available commands or one specific command
  oc.rb node ACTION                          # ノードを操作する
  oc.rb profile ACTION                       # ACTION{prepare|clean}別にプロファイルを操作する
  oc.rb setup TYPE                           # TYPE{aws}別にocの初期設定を行う(アクセスキーの設定など)
  oc.rb sync up|down LOCAL_PATH REMOTE_PATH  # 各ノードとファイルを同期する    
```


### oc setup

環境初期化します。awsのシークレットキーなどを設定します。

```bash
oc setup aws -p [profile] -o [output] -r [region]

# -p プロファイルを指定します。ここで指定したプロファイルで、その後の処理を固定します。デフォルトはdefaultです。
# -o aws-sdkの出力フォーマットを指定します。デフォルトはjsonです。
# -r aws-sdkのリージョンを指定します。デフォルトはus-east-1（バージニア北部リージョン)です。
```


### oc profile prepare

oc のプロファイルを準備します。  
AWSのVPCを初期化したり、必要なセキュリティグループを作成します。

```bash
oc profile prepare -p [profile] --cidr=[CIDR] --subnets=[name/CIDR/mask/auto-ip?]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# --cidr VPCのCIDRを指定します。デフォルトは10.0.0.0/16です。
# --subnets 作成するサブネットを指定します。
#   フォーマットは [subnet-name]/[subnet-CIDR]/[subnet-mask]/[自動でグローバルIPを付与するか] です。
#   デフォルトは public-subnet/10.0.1.0/24/true です。
```


### oc profile clean

プロファイルに関連するVPC設定などを消去します。  
依存するリソースが存在する場合、エラーになります。(terminatedではないインスタンスが存在している場合等)

```bash
oc profile clean -p [profile]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
```


### oc firewall add

プロファイルに関連するVPCのセキュリティグループを追加します。

```bash
oc firewall add [name] -p [profile] -r [rule] -d [description]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r セキュリティグループのルールを記述します。必須です。
#    フォーマットは [in/out]/[tcp/udp/all]/[port/all]/[ip/client/all] です。
#    サンプル: in/tcp/3306/client
# -d セキュリティグループの説明文を指定します。必須です。
```


### oc firewall remove

プロファイルに関連するVPCのセキュリティグループを削除します。

```bash
oc firewall remove [name] -p [profile]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
```


### oc node new

ノードを起動します。どのような設定のインスタンスを作成するかは、後述のロール設定を一読ください。  
ちなみにAZ(availability-zone)は操作簡略化のため region + "a" で固定しています。  
aというAZが存在しない場合、エラーでインスタンスが作成できない可能性が高いです。

```bash
oc node new -p [profile] -t [type] -n [num] -r [role]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r 起動するノードのロールを指定します。デフォルトはdefaultです。必須です。
# -n 起動するノード数を指定します。デフォルトは1です。
# -t 起動するノードのスペックを指定します。(awsであればt2.micro等)必須です。
```


### oc node down

インスタンスを停止します。削除までは行いません。

```bash
oc node down -p [profile] -r [role]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r 停止するノードのロールを指定します。
```


### oc node up

ノードを起動します。

```bash
oc node up -p [profile] -r [role]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r 起動するノードのロールを指定します。
```


### oc node halt

ノードを削除します。

```bash
oc node halt -p [profile] -r [role] -y

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r 削除するロールを指定します。
# -y このオプションを設定すると削除の確認をしません。
```


### oc node ls

ノードのリストを表示します。

```bash
oc node ls -p [profile] -r [role]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r 表示するロールを指定します。
```


### oc node provision

ロールの定義に従って、ノードをプロビジョニングします。
現在対応しているのはchef-solo, chef-zero, ansible, shellです。

```bash
oc node provision -p [profile] -r [role]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r プロビジョニングするロールを指定します。必須です。
```


### oc node ssh

ノードにsshでログインします。

```bash
oc node ssh -p [profile] -i [node-id]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -i ログインするノードのIDを指定します。必須です。ノードのIDはnode lsで確認します。
```


### oc sync up

ローカルからリモートにディレクトリをrsyncします。常にローカルパス リモートパスの順に引数指定します。

```bash
oc sync up /local/path /remote/path -p [profile] -r [role]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r 同期するロールを指定します。
```


### oc sync down

リモートからローカルにrsyncします。常にローカルパス リモートパスの順に引数指定します。  
基本的に、"{/local/path}/node-{public_ip}" に各ノードのディレクトリ内容を同期します。

```bash
oc sync down /local/path /remote/path -p [profile] -r [role]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r 同期するロールを指定します。
```


### oc get

リモートのファイルをSCPダウンロードします。
基本的に現在のディレクトリ以下に "node-{public_ip}" というディレクトリを作成し、ノード別にダウンロードします。

```bash
oc get /remote/path -p [profile] -r [role]

# -p プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# -r 取得するロールを指定します。
```


### oc cmd

各ノードでコマンドを実行します。
-d オプションでディレクトリを同期することで、各ノードにスクリプトを配置して実行させる事も可能です。
さらに、 コマンド文字列内に #index# を与えると、ノード毎に別のインデックス値に置換します。
また、 #nodes# も同様に、全体のノード数に置換します。

```bash
oc cmd "COMMAND" --profile=[profile] --role=[role] --dir=[sync dir]

# ※COMMANDへの干渉を避けるため、cmdのオプションはエイリアスを無効化しています。
# --profile プロファイルを指定します。デフォルトはsetupの際に指定したプロファイルです。
# --role コマンドを実行するロールを指定します。
# --dir ノードと同期するディレクトリを指定します。
```

ノードが4台いる状態での #index# , #nodes# の例  
(ホスト別に並列処理しているため、実際はこのようにきれいな順序では出力されません）

```bash
oc cmd "echo node: #index# / #nodes#"
...
INFO: [xxx.xxx.xxx.xxx] > node: 0 / 4
INFO: [xxx.xxx.xxx.xxx] > node: 1 / 4
INFO: [xxx.xxx.xxx.xxx] > node: 2 / 4
INFO: [xxx.xxx.xxx.xxx] > node: 3 / 4
...
```


# ロール定義ファイルについて

ロール定義ファイルは、ノードをどのような設定で起動するかをYAMLで定義する設定ファイルです。  
ロールはparentを持つことで設定を継承する事ができます。

|オプション|概要|
|---|---|
|image|インスタンスのベースイメージ。awsであればamiのidを指定。|
|role|ロール名。ファイル名と同じにしておく。|
|parent|継承元ロール。|
|firewall|適用するファイアウォール名を記述する。awsの場合はSecurityGroup名。|
|iam_role|IAM RoleのロールARNを記述する。|
|devices|接続するデバイスを定義する。|
|provision|プロビジョニングの設定を記述する。|

デフォルトでは、share/roles/ 以下に web.yml と default.yml を定義しています。  
各コマンドのオプションでロールを指定する際は、このファイル名に付与したロール名を指定してください。

独自のロールを用意する場合、/etc/oc.roles.d/ 以下に [ロール名.yml] という名前のファイルを配置してください。

```bash
cat /etc/oc.roles.d/original_role.yml

image: ami-e3106686
parent: default
role: original_role
firewall:
  - basic-onlyme

iam_role: arn:aws:iam::99999999999:instance-profile/role_name

devices:
  - /dev/xvda:
    size: 10
    type: standard
    ondelete: true

provision:
  repo: git@localhost:user/repo.git
  key: /path/to/.ssh/id_rsa

  type: shell
  option: "yum -y install httpd"
```

なお、組み込みで提供しているfirewall(セキュリティグループ)は以下の3つです。

- basic-onlyme: oc実行マシンのグローバルIPからはどのプロトコル・ポートでも疎通可能
- basic-login : oc実行マシンのグローバルIPからのみtcp 22番を疎通可能
- basic-http  : tcp 80,443をanyで疎通可能

ちなみにoc実行マシンのグローバルIPは、 http://checkip.amazonaws.com/ で行っています。


# 分散処理サンプル

複数のノードで分散処理を行い、結果を取得するサンプルです。

下準備として、このような ruby スクリプトを準備します。  
100万までの数値について、sha1のハッシュ値を計算します。  
引数にノードのインデックスとノード数を渡して、ノード毎に処理する範囲を変えます。

```ruby
require 'digest/sha1'

step = 1000000 / ARGV[1].to_i
from = ARGV[0].to_i * step
to = from + step

(from..to).each do |num|
  puts Digest::SHA1.hexdigest(num.to_s)
end
```

ocでノードを10台用意し、rubyをインストールした後、スクリプトを実行します。

```bash
$ oc node new -t t2.micro -r default -n 10

$ oc cmd "sudo yum install -y ruby"

$ oc cmd "ruby hash.rb #index# #nodes# > hashed.txt"

$ oc get hashed.txt
```

これでディレクトリ直下にノード毎の結果が帰ってくるはず。

```bash
$ ls -l node*
node-xxx.xxx.xxx.xxx:
total xxxxx
-rw-rw-r-- 1 user user xxxxxxxx Oct 10 00:00 hashed.txt

node-xxx.xxx.xxx.xxx:
total xxxxx
-rw-rw-r-- 1 user user xxxxxxxx Oct 10 00:00 hashed.txt
```


# その他

* awsのリージョンをus-east-1以外に設定した場合  
→amiがリージョン毎に異なる為、share/roles/defualt.yml を編集して、適切なamiに変更してください。



# ライセンス

MITライセンスに準拠します



# 免責

本ソフトウェアによって起こったいかなる事象についても制作者は責任を負いません。  
すべて自己責任にてご利用ください。

