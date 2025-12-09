#/bin/bash

sudo passwd
df . -h
du / -sh
lspci -d 1e52:

## Install Software Dependencies
sudo apt update && sudo apt install -y wget git python3-pip dkms cargo python3-venv vim

python3 -m venv ~/.tenstorrent-venv
echo "source ~/.tenstorrent-venv/bin/activate" >> ~/.bash_aliases

## Install Docker
## https://docs.docker.com/engine/install/ubuntu/
## https://docs.docker.com/engine/install/linux-postinstall/

mkdir code
cd code

## Install the Kernel-Mode Driver (TT-KMD)
git clone https://github.com/tenstorrent/tt-kmd.git
cd tt-kmd
git checkout ttkmd-2.5.0-rc1
sudo dkms add .
sudo dkms install tenstorrent/2.5.0-rc1
sudo modprobe tenstorrent
lsmod | grep tenstorrent
cd ..

## Device Firmware Update (TT-Flash / TT-Firmware)
pip install git+https://github.com/tenstorrent/tt-flash.git@v3.4.7
wget https://github.com/tenstorrent/tt-firmware/releases/download/v19.2.0/fw_pack-19.2.0.fwbundle
tt-flash --fw-tar fw_pack-19.2.0.fwbundle --force
sudo reboot

## Set Up HugePages
wget https://github.com/tenstorrent/tt-system-tools/releases/download/v1.4.0/tenstorrent-tools_1.4.0_all.deb
sudo dpkg -i tenstorrent-tools_1.4.0_all.deb
sudo systemctl enable --now tenstorrent-hugepages.service
sudo systemctl enable --now 'dev-hugepages\x2d1G.mount'
sudo reboot

## Multi-Card Configuration (TT-Topology)
pip install git+https://github.com/tenstorrent/tt-topology@v1.2.15
tt-topology -l mesh

## Install the System Management Interface (TT-SMI)
pip install git+https://github.com/tenstorrent/tt-smi@v3.0.37

## Install ttnn-visualizer
pip install git+https://github.com/tenstorrent/ttnn-visualizer@v0.63.1

## TT-NN / TT-Metalium Installation
git clone https://github.com/tenstorrent/tt-metal.git
cd tt-metal
git checkout v0.64.5-rc3
git submodule update --init --recursive
sudo ./install_dependencies.sh
./build_metal.sh -b RelWithDebInfo --build-all

export TT_METAL_HOME=~/code/tt-metal
export PYTHON_ENV_DIR=~/.tenstorrent-venv
export PYTHONPATH=$(TT_METAL_HOME)

$TT_METAL_HOME/create_venv.sh
source $(PYTHON_ENV_DIR)/bin/activate
python3 -m ttnn.examples.usage.run_op_on_device
~/code/tt-metal/models/experimental/stable_diffusion_xl_base/tests$ PYTHONPATH=~/code/tt-metal/ pytest ./test_sdxl_inpaint_accuracy.py
cd ..

## Install model
pip install -U huggingface_hub transformers
huggingface-cli login
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct

## Install tt-inference-server
git clone https://github.com/tenstorrent/tt-inference-server.git
cd tt-inference-server
git checkout v0.4.0

export HF_TOKEN="hf_..."
export JWT_SECRET="testing"
export DEVICE="p150"
export MODEL="Llama-3.1-8B-Instruct"

python3 run.py \
  --model "$MODEL" \
  --device "$DEVICE" \
  --workflow server \
  --docker-server \
  --override-docker-image ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-release-ubuntu-22.04-amd64:0.4.0-e95ffa5-48eba14 \
  --override-tt-config '{
    "trace_region_size": 50000000,
    "enable_fast_runtime_mode": false,
    "enable_logging": true,
    "report_name": "vllm",
    "enable_graph_report": false,
    "enable_detailed_buffer_report": true,
    "enable_detailed_tensor_report": false,
    "enable_comparison_mode": false}'

## JWT_SECRET
pip3 install --upgrade pip
pip install pyjwt==2.7.0
export VLLM_API_KEY=$(python3 -c 'import os; import json; import jwt; json_payload = json.loads("{\"team_id\": \"tenstorrent\", \"token_id\": \"debug-test\"}"); encoded_jwt = jwt.encode(json_payload, os.environ["JWT_SECRET"], algorithm="HS256"); print(encoded_jwt)')

## verify vllm
curl -sS "http://localhost:32156/v1/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VLLM_API_KEY" \
  -d "{
    \"model\": \"meta-llama/$MODEL\",
    \"prompt\": \"San Francisco is a\",
    \"max_tokens\": 50,
    \"temperature\": 0
  }" | jq

## vllm docker deployment
mkdir -p vllm-llama31-8b-p150
cp ~/code/tt-inference-server/.env ~/code/vllm-llama31-8b-p150/.env
mv ~/code/tt-inference-server/persistent_volume ~/code/vllm-llama31-8b-p150/
## save the latest .json spec as tt_model_spec.json
mv ~/code/tt-inference-server/workflow_logs/run_specs ~/code/vllm-llama31-8b-p150/

docker run --rm \
  --name vllm-llama31-8b-p150 \
  --env-file /home/uraina/code/vllm-llama31-8b-p150/.env \
  --cap-add ALL \
  --device /dev/tenstorrent:/dev/tenstorrent \
  --mount type=bind,src=/dev/hugepages-1G,dst=/dev/hugepages-1G \
  --mount type=bind,src=/home/uraina/code/vllm-llama31-8b-p150/persistent_volume/volume_id_tt_transformers-Llama-3.1-8B-Instruct-v0.4.0,dst=/home/container_app_user/cache_root \
  --mount type=bind,src=/home/uraina/.cache/huggingface/hub/models--meta-llama--Llama-3.1-8B-Instruct,dst=/home/container_app_user/readonly_weights_mount/Llama-3.1-8B-Instruct,readonly \
  --mount type=bind,src=/home/uraina/code/vllm-llama31-8b-p150/run_specs/tt_model_spec.json,dst=/home/container_app_user/model_spec/tt_model_spec.json,readonly \
  --shm-size 32G \
  --publish 8000:8000 \
  -e CACHE_ROOT=/home/container_app_user/cache_root \
  -e TT_CACHE_PATH=/home/container_app_user/cache_root/tt_metal_cache/cache_Llama-3.1-8B-Instruct/P150 \
  -e MODEL_WEIGHTS_PATH=/home/container_app_user/readonly_weights_mount/Llama-3.1-8B-Instruct/snapshots/0e9e39f249a16976918f6564b8830bc894c89659/original \
  -e TT_LLAMA_TEXT_VER=tt_transformers \
  -e TT_MODEL_SPEC_JSON_PATH=/home/container_app_user/model_spec/tt_model_spec.json \
  ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-release-ubuntu-22.04-amd64:0.4.0-e95ffa5-48eba14

check_server_health() {
    local URL="http://10.200.50.43:8000/health"
    local code

    code=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    if [[ $? -ne 0 ]]; then
        echo "__ Error: Unable to connect to server at 10.200.50.43:8000"
        return 1
    fi

    if [[ "$code" -eq 200 ]]; then
        echo "__ Server is ready (HTTP 200)"
    else
        echo "__ Server responded with status: $code"
    fi
}

## Install k3s
curl -sfL https://get.k3s.io | sh -
sudo cat /var/lib/rancher/k3s/server/node-token
sudo kubectl get nodes

## Apply code/vllm-llama31-8b-p150
kubectl apply -f ~/code/vllm-llama31-8b-p150/tenstorrent-device-plugin.yaml
kubectl -n kube-system get pods -o wide | grep tenstorrent-device-plugin
kubectl describe nodes | grep tenstorrent

kubectl create secret generic vllm-llama31-8b-p150-env \
        --from-env-file=/home/uraina/code/vllm-llama31-8b-p150/.env

kubectl apply -f vllm-llama31-8b-p150-headless-service.yaml
kubectl apply -f vllm-llama31-8b-p150-headless-service.yaml
kubectl apply -f vllm-llama31-8b-p150-service.yaml

## kubectl commands for managing
kubectl apply -f /home/uraina/code/vllm-llama31-8b-p150/vllm-llama31-8b-p150.yaml
kubectl get pods
kubectl get svc
kubectl get statefulset
kubectl get pods -w

kubectl describe pod <>
kubectl logs -f <>

kubectl describe pod vllm-llama31-8b-p150-0
kubectl describe pod vllm-llama31-8b-p150-1

kubectl logs -f vllm-llama31-8b-p150-0
kubectl logs -f vllm-llama31-8b-p150-1

kubectl delete pod --ignore-not-found vllm-llama31-8b-p150-0
kubectl delete pod --ignore-not-found vllm-llama31-8b-p150-1

kubectl exec -it vllm-llama31-8b-p150-0 -- bash
kubectl exec -it vllm-llama31-8b-p150-1 -- bash

kubectl get ds -n kube-system
kubectl get pods -n kube-system

## vllm
git clone git@github.com:tenstorrent/vllm.git
cd vllm

# Add the original vLLM repo as "upstream"
git remote add upstream git@github.com:vllm-project/vllm.git

# Fetch both remotes
git fetch origin
git fetch upstream
git diff "$(git merge-base upstream/main origin/main)"..origin/main

## vllm production stack
git clone https://github.com/vllm-project/production-stack.git
cd production-stack
git checkout vllm-stack-0.1.8

cd production-stack/utils
bash install-kubectl.sh
bash install-helm.sh
bash install-minikube-cluster.sh

helm repo add vllm https://vllm-project.github.io/production-stack
helm repo update
helm install vllm vllm/vllm-stack -f ../vllm-llama31-8b-p150/values-tenstorrent.yaml

kubectl get pods
kubectl describe pod vllm-deployment-router-
kubectl delete pod vllm-deployment-router-

export PATH=/home/uraina/.local/bin/:$PATH
