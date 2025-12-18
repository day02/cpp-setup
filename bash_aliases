#!/bin/bash

[ -z "$TMUX"  ] && { tmux attach || exec tmux new-session && exit;}

alias gl="git log --graph --decorate --abbrev-commit --all"
alias rex="killall emacs; source ~/.venv/bin/activate; emacs --daemon; x"
alias x="emacsclient -nw ."
alias ..="cd .."
export EDITOR="x"

export CODE_DIR="/home/uraina/code"
alias code="cd $CODE_DIR"

ssl() {
	ssh uraina@uraina-lab
}

scl() {
	scp -r "$1" uraina@uraina-lab:"$2"
}

export OS_TYPE="linux"

function osq-mksys()
{
    #rm -rf cd $CODE_DIR/osquery/build/*
    #rm -rf cd $CODE_DIR/.deps/*
    docker stop osquery.$OS_TYPE osquery.$OS_TYPE.template
    docker rm osquery.$OS_TYPE osquery.$OS_TYPE.template
    docker rmi osquery.$OS_TYPE osquery.$OS_TYPE.template
    docker images -a
    docker ps -a
    docker build $CODE_DIR -f $CODE_DIR/Dockerfile.$OS_TYPE \
           -t osquery.$OS_TYPE.template --build-arg user=uraina
    docker run -v $CODE_DIR/osquery:$CODE_DIR/osquery:rw \
               -v $CODE_DIR/.deps:/usr/local/osquery:rw \
               --name osquery.$OS_TYPE.template \
               -it osquery.$OS_TYPE.template \
               mk-sys
    docker commit osquery.$OS_TYPE.template osquery.$OS_TYPE
    docker stop osquery.$OS_TYPE.template
    docker rm osquery.$OS_TYPE.template
    osq-new-container
}

function osq-new-container()
{
    docker stop osquery.$OS_TYPE
    docker rm osquery.$OS_TYPE
    docker ps -a
    docker run --detach \
           -v $CODE_DIR/osquery:$CODE_DIR/osquery:rw \
           -v $CODE_DIR/.deps:/usr/local/osquery:rw \
           --name osquery.$OS_TYPE \
           -it osquery.$OS_TYPE \
           bash
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

function osq-mkr()
{
    docker exec -it osquery.$OS_TYPE mkr
}

function osq-mkrt()
{
    docker exec -it osquery.$OS_TYPE mkrt
}

function osq-mk-rem()
{
    docker exec -it osquery.$OS_TYPE mk-rem
}

function osq-mk-tidy()
{
    docker exec -it osquery.$OS_TYPE mk-tidy
}

function osq-mk-valgrind()
{
    docker exec -it osquery.$OS_TYPE mk-valgrind
}

function json-pretty()
{
    python3 -m json.tool $1
}

function ssm-dev()
{
    #ssh uraina@uraina-dev2.local 'while true; do echo -n .; sleep 0.1; done' > /dev/null
    ssh uraina@uraina-dev2.local
}

function ssm-win()
{
    ssh -p 3025 uraina@127.0.0.1
}

function ssm-colo()
{
    ssh -A -o proxyJump=uraina@192.168.151.24 ubuntu@$1
}

function scp-colo()
{
    scp -A -o proxyJump=uraina@192.168.151.24 $1 ubuntu@$2
}
