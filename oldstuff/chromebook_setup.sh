#! /bin/bash

set -euo pipefail

sudo apt-get update

# Generally useful dev stuff
sudo apt-get install -y \
  coreutils manpages man-db \
  python3 python3-distutils python3-dev \
  bash-completion \
  tmux screen \
  silversearcher-ag jq \
  wget curl net-tools iputils-ping dnsutils \
  entr golang bc \
  zsh zsh-doc

# For Bazel to work
sudo apt-get install -y \
  python2 \
  pkg-config zip unzip \
  g++ zlib1g-dev \
  openjdk-11-jdk-headless
# Bad thing, but this is needed for bazel
sudo ln -s /usr/bin/python2 /usr/bin/python


BAZEL_VERSION=3.4.1
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


# For VScode, copied from https://code.visualstudio.com/docs/setup/linux
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'

sudo apt-get install -y apt-transport-https
sudo apt-get update
sudo apt-get install -y code
