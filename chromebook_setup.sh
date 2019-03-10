#! /bin/bash

set -euo pipefail

sudo apt-get update

# Generally useful dev stuff
sudo apt-get install -y \
  coreutils python3 manpages man-db \
  bash-completion \
  tmux screen \
  silversearcher-ag jq \
  wget curl net-tools iputils-ping dnsutils \
  entr golang bc
  


# For Bazel to work
sudo apt-get install -y \
  python2.7 python2.7-dev \
  pkg-config zip unzip \
  g++ zlib1g-dev \
  openjdk-8-jdk-headless


BAZEL_VERSION=0.22.0
OS=linux
if [ ! -e ~/bazel-install-$BAZEL_VERSION.sh ] ; then
  wget -O ~/bazel-install-$BAZEL_VERSION.sh https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-${OS}-x86_64.sh
  chmod +x ~/bazel-install-$BAZEL_VERSION.sh
fi
~/bazel-install-$BAZEL_VERSION.sh --user
# rm -f bazel-install.sh

# For docker, from https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-using-the-repository
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
sudo apt-get update

# Hopefully temporary changes, see https://github.com/docker/for-linux/issues/475#issuecomment-437373774
sudo mkdir -p /etc/systemd/system/containerd.service.d
echo "[Service]
ExecStartPre=" | sudo tee /etc/systemd/system/containerd.service.d/override.conf

sudo apt-get install -y docker-ce

# ick
sudo curl -L https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m` -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose

