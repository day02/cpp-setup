#!/bin/bash

[ -z "$TMUX"  ] && { tmux attach || exec tmux new-session && exit;}

alias gl="git log --graph --decorate --abbrev-commit --all"
alias rex="osq-container && killall emacs; emacs --daemon; x"
alias x="emacsclient -nw ."
alias ..="cd .."
export EDITOR="x"

export CODE_DIR="/home/uraina/code"
alias code="cd $CODE_DIR"
alias osq="cd $CODE_DIR/osquery"
alias build="cd $CODE_DIR/osquery/build/debug_linux/osquery"

export OS_TYPE="linux"

function osq-mksys()
{
    rm -rf cd $CODE_DIR/osquery/build/*
    docker stop osquery.$OS_TYPE
    docker rm osquery.$OS_TYPE
    docker rmi osquery.$OS_TYPE
    docker images -a
    docker ps -a
    docker build $CODE_DIR -f $CODE_DIR/Dockerfile.$OS_TYPE \
           -t osquery.$OS_TYPE --build-arg user=uraina
    docker run --detach \
           -v $CODE_DIR/osquery/osquery:$CODE_DIR/osquery/osquery \
           -v $CODE_DIR/osquery/specs:$CODE_DIR/osquery/specs \
           -v $CODE_DIR/osquery/build:$CODE_DIR/osquery/build \
           --name osquery.$OS_TYPE  -it osquery.$OS_TYPE bash
}

function osq-new-container()
{
    docker stop osquery.$OS_TYPE
    docker rm osquery.$OS_TYPE
    docker ps -a
    docker run --detach \
           -v $CODE_DIR/osquery/osquery:$CODE_DIR/osquery/osquery \
           -v $CODE_DIR/osquery/specs:$CODE_DIR/osquery/specs \
           -v $CODE_DIR/osquery/build:$CODE_DIR/osquery/build \
           --name osquery.$OS_TYPE  -it osquery.$OS_TYPE bash
}

function osq-container()
{
    docker stop osquery.$OS_TYPE
    docker start osquery.$OS_TYPE
}

function osq-shell()
{
    docker exec -it osquery.$OS_TYPE bash
}

function osq-mk()
{
    docker exec -it osquery.$OS_TYPE mk
}

function osq-mkt()
{
    docker exec -it osquery.$OS_TYPE mkt
}

function osq-mk-tidy()
{
    docker exec -it osquery.$OS_TYPE mk-tidy
}

function json-pretty()
{
    python3 -m json.tool $1
}

function ssm()
{
    ssh -p 3022 uraina@127.0.0.1
}

function ssm-lxd()
{
    ssh -p 3023 uraina@127.0.0.1
}

function ssm-crio()
{
    ssh -p 3024 uraina@127.0.0.1
}
