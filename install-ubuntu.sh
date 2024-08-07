#/bin/bash

sudo add-apt-repository ppa:kelleyk/emacs
sudo apt update
sudo apt upgrade --assume-yes

sudo apt install --assume-yes build-essential
sudo apt install --assume-yes python3-distutils
sudo apt install --assume-yes python3-pip
sudo apt install --assume-yes git
sudo apt install --assume-yes vim
sudo apt install --assume-yes emacs28
sudo apt install --assume-yes global
sudo apt install --assume-yes clang-format
sudo apt install --assume-yes clang-tidy
sudo apt install --assume-yes sshpass
sudo apt install --assume-yes valgrind
sudo apt install --assume-yes tmux

sudo apt install --assume-yes clang
sudo apt install --assume-yes gcc
sudo apt install --assume-yes g++
sudo apt install --assume-yes cmake
sudo apt install --assume-yes ninja-build
sudo apt install --assume-yes make
sudo apt install --assume-yes gdb
sudo apt install --assume-yes tree
sudo apt install --assume-yes htop

sudo apt autoremove --assume-yes -f
sudo apt purge --assume-yes
sudo apt clean --assume-yes

## git config --global push.default "tracking"
## git config --global user.name "uday raina"
## git config --global user.email "udayrainaz@gmail.com"
## git config --global core.editor "vim"
## git config --global diff.tool "vimdiff"
## git config --global difftool.prompt "no"

## nvidia install CUDA
## https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
