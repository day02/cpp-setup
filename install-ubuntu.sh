#/bin/bash

sudo add-apt-repository ppa:kelleyk/emacs
sudo apt update
sudo apt upgrade -y

sudo apt install -y build-essential
sudo apt install -y python3-distutils
sudo apt install -y python3-pip
sudo apt install -y git
sudo apt install -y vim
sudo apt install -y emacs28
sudo apt install -y global
sudo apt install -y clang-format
sudo apt install -y clang-tidy
sudo apt install -y sshpass
sudo apt install -y valgrind
sudo apt install -y tmux

sudo apt install -y clang
sudo apt install -y gcc
sudo apt install -y g++
sudo apt install -y cmake
sudo apt install -y ninja-build
sudo apt install -y make
sudo apt install -y gdb
sudo apt install -y tree
sudo apt install -y htop
sudo apt install -y meld

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

## nvidia install CUDA
## https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
