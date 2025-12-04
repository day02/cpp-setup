#/bin/bash

## Install Software Dependencies
sudo apt update
sudo apt upgrade -y

sudo apt update && sudo apt install -y wget git python3-pip dkms cargo

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
./install_dependencies.sh
./build_metal.sh -b RelWithDebInfo --build-all

export TT_METAL_HOME=~/code/tt-metal 
export PYTHON_ENV_DIR=~/.tenstorrent-venv 
export PYTHONPATH=$(TT_METAL_HOME)

$TT_METAL_HOME/create_venv.sh
source $(PYTHON_ENV_DIR)/bin/activate
python3 -m ttnn.examples.usage.run_op_on_device
~/code/tt-metal/models/experimental/stable_diffusion_xl_base/tests$ PYTHONPATH=~/code/tt-metal/ pytest ./test_sdxl_inpaint_accuracy.py
cd ..

## tt-inference-server
git clone https://github.com/tenstorrent/tt-inference-server.git
cd tt-inference-server

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

## vllm
git clone git@github.com:tenstorrent/vllm.git
cd vllm

# Add the original vLLM repo as "upstream"
git remote add upstream git@github.com:vllm-project/vllm.git

# Fetch both remotes
git fetch origin
git fetch upstream
git diff "$(git merge-base upstream/main origin/main)"..origin/main

# JWT_SECRET
pip3 install --upgrade pip
pip install pyjwt==2.7.0
export VLLM_API_KEY=$(python3 -c 'import os; import json; import jwt; json_payload = json.loads("{\"team_id\": \"tenstorrent\", \"token_id\": \"debug-test\"}"); encoded_jwt = jwt.encode(json_payload, os.environ["JWT_SECRET"], algorithm="HS256"); print(encoded_jwt)')
curl -sS "http://localhost:8000/v1/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VLLM_API_KEY" \
  -d "{
    \"model\": \"meta-llama/$MODEL\",
    \"prompt\": \"San Francisco is a\",
    \"max_tokens\": 50,
    \"temperature\": 0
  }" | jq
