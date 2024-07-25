#/bin/bash

####
## make bash as default
## chsh -s /bin/bash
## install homebrew
####

brew update

brew install git
brew install vim
brew install --cask emacs
brew install global
brew install clang-format
brew install tmux

brew install llvm
brew install gcc
brew install g++
brew install cmake
brew install ninja
brew install make
brew install gdb
brew install tree
brew install htop
brew install docker

brew cleanup

## Virtual Box
## sudo dpkg-reconfigure virtualbox-dkms
## sudo apt install --assume-yes virtualbox

## git config --global push.default "tracking"
## git config --global user.name "uday raina"
## git config --global user.email "udayrainaz@gmail.com"
## git config --global core.editor "vim"
## git config --global diff.tool "vimdiff"
## git config --global difftool.prompt "no"

## nvidia install CUDA
## https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
