#!/bin/sh

# sudo 時の PATH を設定
sudo bash -c "echo 'Defaults env_keep += PATH' > /etc/sudoers.d/oc_config";
sudo bash -c "echo 'Defaults secure_path = /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> /etc/sudoers.d/oc_config"

sudo yum install -y -q ruby-devel gcc-c++ git
sudo gem install -q --no-rdoc --no-ri chef


