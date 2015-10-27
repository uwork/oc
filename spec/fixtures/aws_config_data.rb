#-*- encoding: utf-8 -*-

# AwsConfig用のテストデータ
module AwsConfigData
  ACCESS_KEY_ID = "xxxxxxxxxxxx"
  SECRET_KEY = "xxxxxxxxxxxxxxxx"

  AWS_CREDENTIALS_PATH = "/tmp/.aws_credentials"
  AWS_CONFIG_PATH = "/tmp/.aws_config"

  AWS_CREDENTIALS_CONTENT =<<EOF
[test]
aws_access_key_id = #{ACCESS_KEY_ID}
aws_secret_access_key = #{SECRET_KEY}

EOF

  AWS_CONFIG_CONTNT =<<EOF
[test]
region = us-east-1
output = json

EOF

end
