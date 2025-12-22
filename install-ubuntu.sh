#/bin/bash

sudo add-apt-repository ppa:kelleyk/emacs

sudo apt update
sudo apt upgrade -y

sudo apt install -y \
  vim tmux git curl tree htop meld gdb valgrind \
  build-essential ca-certificates pkg-config \
  gcc g++ clang clangd clang-format clang-tidy cmake make ninja-build gdb \
  python3 python3-pip python3-venv \
  emacs elpa-vterm ripgrep fd-find libvterm-dev

## emacs settings
python3 -m venv ~/.venv
source ~/.venv/bin/activate
python3 -m pip install --upgrade setuptools
python3 -m pip install black isort aider-chat

sudo apt install -y nodejs npm
sudo npm install -g pyright

## virtualization
sudo apt install -y vagrant \
     vagrant-libvirt qemu-kvm \
     libvirt-clients libvirt-daemon-system \
     bridge-utils

## Tenstorrent
sudo apt install -y wget dkms cargo

sudo apt autoremove -yf
sudo apt purge -y
sudo apt clean -y

## git config --global push.default "tracking"
## git config --global user.name "uday raina"
## git config --global user.email "udayrainaz@gmail.com"
## git config --global core.editor "vim"
## git config --global diff.tool "vimdiff"
## git config --global difftool.prompt "no"

## gtags --gtagslabel=ctags

## nvidia install CUDA
## https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
