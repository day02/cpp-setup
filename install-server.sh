#/bin/bash

## Install Software Dependencies and virtual python env
sudo apt update && sudo apt install -y wget git python3-pip python3-venv vim curl

mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
docker compose version

python3 -m venv ~/.tenstorrent-venv
echo "source ~/.tenstorrent-venv/bin/activate" >> ~/.bash_aliases

## Upgrade packaging tools
python -m pip install -U pip setuptools wheel

## Install the System Management Interface (TT-SMI)
pip install -U git+https://github.com/tenstorrent/tt-smi@v3.0.37

## Install k3s
curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER":"$USER" ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

sudo cat /var/lib/rancher/k3s/server/node-token
kubectl get nodes && kubectl get all

## helm
cd /tmp
curl -fsSL https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz -o helm.tar.gz
tar -xzf helm.tar.gz
sudo mv /tmp/linux-amd64/helm /usr/bin/helm
rm -rf /tmp/linux-amd64 /tmp/helm.tar.gz
cd -

helm version

## Download the repository
mkdir -p ~/code
cd ~/code
git clone git@github.com:turiyamai/foundry.git
cd ~/code/foundry

## Download the models
## Refer to
## - foundry/models/llama3.1-8b/README.md
## - foundry/models/qwen2.5-vl-3b-instruct/README.md

## Apply helm charts for foundry
## Refer to
## - foundry/README.md - Deploy the secrets
## - foundry/README.md - Deploy the foundry
