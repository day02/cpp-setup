#/bin/bash

sudo passwd
df . -h
du / -sh
lspci -d 1e52:

## sudo vi /etc/hosts
## add ip uraina-lab

## Install Software Dependencies
sudo apt update && sudo apt install -y wget git python3-pip dkms cargo python3-venv vim clang

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
export PYTHONPATH=$TT_METAL_HOME

$TT_METAL_HOME/create_venv.sh
source $PYTHON_ENV_DIR/bin/activate
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
git checkout v0.8.0

export HF_TOKEN="hf_..."
export JWT_SECRET="testing"

export DEVICE="p150"
export MODEL="Llama-3.1-8B-Instruct"

python3 run.py \
  --model "$MODEL" \
  --device "$DEVICE" \
  --workflow server \
  --docker-server \
  --override-docker-image ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-dev-ubuntu-22.04-amd64:0.5.0-fbbbd2d-7a9b86f \
  --override-tt-config '{
    "trace_region_size": 50000000,
    "enable_fast_runtime_mode": false,
    "enable_logging": true,
    "report_name": "vllm",
    "enable_graph_report": false,
    "enable_detailed_buffer_report": true,
    "enable_detailed_tensor_report": false,
    "enable_comparison_mode": false}'

docker run --rm \
  --name tt-inference-server-38d13d80 \
  --cap-add ALL \
  --device /dev/tenstorrent:/dev/tenstorrent \
  --shm-size 32G \
  --publish 8000:8000 \
  --env-file /home/uraina/code/tt-inference-server/.env \
  -e CACHE_ROOT=/home/container_app_user/cache_root \
  -e TT_CACHE_PATH=/home/container_app_user/cache_root/tt_metal_cache/cache_Llama-3.1-8B-Instruct/P150 \
  -e MODEL_WEIGHTS_PATH=/home/container_app_user/readonly_weights_mount/Llama-3.1-8B-Instruct/snapshots/0e9e39f249a16976918f6564b8830bc894c89659 \
  -e TT_MODEL_SPEC_JSON_PATH=/home/container_app_user/model_spec/tt_model_spec_2026-01-19_08-20-51_id_tt-transformers_Llama-3.1-8B-Instruct_p150_server_BaSZTFh1.json \
  --mount type=bind,src=/dev/hugepages-1G,dst=/dev/hugepages-1G \
  --mount type=bind,src=/home/uraina/code/tt-inference-server/persistent_volume/volume_id_tt_transformers-Llama-3.1-8B-Instruct-v0.8.0,dst=/home/container_app_user/cache_root \
  --mount type=bind,src=/home/uraina/code/tt-inference-server/workflow_logs/run_specs/tt_model_spec_2026-01-19_08-20-51_id_tt-transformers_Llama-3.1-8B-Instruct_p150_server_BaSZTFh1.json,dst=/home/container_app_user/model_spec/tt_model_spec_2026-01-19_08-20-51_id_tt-transformers_Llama-3.1-8B-Instruct_p150_server_BaSZTFh1.json,readonly \
  --mount type=bind,src=/home/uraina/.cache/huggingface/hub/models--meta-llama--Llama-3.1-8B-Instruct,dst=/home/container_app_user/readonly_weights_mount/Llama-3.1-8B-Instruct,readonly \
  ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-dev-ubuntu-22.04-amd64:0.8.0-a9b09e0-a186bf4

curl -sS "http://localhost:8000/v1/completions" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $VLLM_API_KEY" \
     -d "{
    \"model\": \"meta-llama/$MODEL\",
    \"prompt\": \"San Francisco is a\",
    \"max_tokens\": 50,
    \"temperature\": 0
  }" | jq


#####################

export DEVICE="n300"
export MODEL="Qwen2.5-VL-3B-Instruct"

python3 run.py \
        --model "$MODEL" \
        --device "$DEVICE" \
        --workflow server \
        --docker-server \
        --impl tt-transformers \
        --override-docker-image ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-dev-ubuntu-22.04-amd64:0.5.0-fbbbd2d-7a9b86f

docker run --rm \
  --name tt-inference-server-426e9f8f \
  --env-file /home/uraina/code/tt-inference-server/.env \
  --cap-add ALL \
  --device /dev/tenstorrent:/dev/tenstorrent \
  --shm-size 32G \
  --publish 8000:8000 \
  --mount type=bind,src=/dev/hugepages-1G,dst=/dev/hugepages-1G \
  --mount type=bind,src=/home/uraina/code/tt-inference-server/persistent_volume/volume_id_tt_transformers-Qwen2.5-VL-3B-Instruct-v0.4.0,dst=/home/container_app_user/cache_root \
  --mount type=bind,src=/home/uraina/code/tt-inference-server/workflow_logs/run_specs/tt_model_spec.json,dst=/home/container_app_user/model_spec/tt_model_spec.json,readonly \
  --mount type=bind,src=/home/uraina/.cache/huggingface/hub/models--Qwen--Qwen2.5-VL-3B-Instruct,dst=/home/container_app_user/readonly_weights_mount/Qwen2.5-VL-3B-Instruct,readonly \
  -e CACHE_ROOT=/home/container_app_user/cache_root \
  -e TT_CACHE_PATH=/home/container_app_user/cache_root/tt_metal_cache/cache_Qwen2.5-VL-3B-Instruct/N300 \
  -e MODEL_WEIGHTS_PATH=/home/container_app_user/readonly_weights_mount/Qwen2.5-VL-3B-Instruct/snapshots/66285546d2b821cf421d4f5eb2576359d3770cd3 \
  -e TT_MODEL_SPEC_JSON_PATH=/home/container_app_user/model_spec/tt_model_spec.json \
  ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-dev-ubuntu-22.04-amd64:0.5.0-fbbbd2d-7a9b86f

curl http://localhost:8000/v1/chat/completions \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $VLLM_API_KEY" \
     -d '{
    \"model\": \"Qwen/$MODEL\",
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": [
          { \"type\": \"text\", \"text\": \"What is shown in this image?\" },
          {
            \"type\": \"image_url\",
            \"image_url\": {
              \"url\": \"https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/640px-PNG_transparency_demonstration_1.png\"
            }
          }
        ]
      }
    ]
  }'

#####################

## tt-media-server
cd tt-inference-server/tt-media-server
git checkout ff12066f4c906d043f992ab10e02e4080414064c ## dev
sudo apt update && sudo apt install -y ffmpeg && pip install -r requirements.txt

export MODEL_RUNNER=tt-sdxl-edit
export MODEL=stable-diffusion-xl-1.0-inpainting-0.1
export DEVICE=p150
export API_KEY=testing
export LOG_FILE=/tmp/tt.log
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1 --lifespan on

curl -s http://127.0.0.1:8000/openapi.json | jq '.paths | keys'
curl -X 'POST' \
     'http://127.0.0.1:8000/image/edits' \
     -H 'accept: application/json' \
     -H 'Authorization: Bearer testing' \
     -H 'Content-Type: application/json' \
     -d '{
  "prompt": "Volcano on a beach",
  "negative_prompt": "low quality",
  "num_inference_steps": 20,
  "seed": 0,
  "guidance_scale": 7.0,
  "number_of_images": 1
}'

ssh -L 8000:localhost:8000 uraina@uraina-lab

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
curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" \
                    sh -
sudo cat /var/lib/rancher/k3s/server/node-token
kubectl get nodes

sudo /usr/local/bin/k3s-killall.sh
sudo /usr/local/bin/k3s-uninstall.sh
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /var/lib/rancher/k3s

## helm
cd /tmp
curl -fsSL https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz -o helm.tar.gz
tar -xzf helm.tar.gz
sudo mv /tmp/linux-amd64/helm /usr/bin/helm
rm -rf /tmp/linux-amd64 /tmp/helm.tar.gz
cd -

helm version

sudo mkdir -p /opt/foundry/models/Llama-3.1-8B-Instruct/original
rsync -avL \
      ~/.cache/huggingface/hub/models--meta-llama--Llama-3.1-8B-Instruct/snapshots/*/original/ \
      /opt/foundry/models/Llama-3.1-8B-Instruct/original/
sudo cp llama3.1-8b/tt_model_spec.json /opt/foundry/models/Llama-3.1-8B-Instruct/

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER":"$USER" ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

helm lint charts/foundry
helm install foundry charts/foundry \
     --namespace foundry \
     --create-namespace
helm upgrade --install foundry charts/foundry \
     --namespace foundry

helm uninstall foundry -n foundry

kubectl get all -n foundry

kubectl get pods -n kube-system | grep tt
kubectl get pods -n foundry
kubectl get svc -n foundry

kubectl describe -n foundry pod foundry-llama-3-1-8b-0
kubectl logs -n foundry -f foundry-llama-3-1-8b-0

kubectl describe -n foundry pod foundry-qwen2-5-vl-3b-instruct-0
kubectl logs -n foundry -f foundry-qwen2-5-vl-3b-instruct-0

kubectl exec -it -n foundry foundry-llama-3-1-8b-0 -- /bin/bash

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

## tt-xla
git clone https://github.com/tenstorrent/tt-xla.git
cd tt-xla
git submodule update --init --recursive

## tt-xla
docker run -it --rm \
       --name tt-xla-dev \
       --device /dev/tenstorrent \
       --publish 8000:8000 \
       -v /dev/hugepages-1G:/dev/hugepages-1G \
       -v /home/uraina/code/tt-xla:/tt-xla \
       -v ~/.cache/huggingface:/root/.cache/huggingface \
       ghcr.io/tenstorrent/tt-xla/tt-xla-slim:409c0ef74bfcb2c2bd8f848c200a0f67397231d6

apt-get update && apt-get install -y libnuma-dev

cd /tt-xla
source /tt_xla/venv/activate

export CMAKE_DISABLE_FIND_PACKAGE_CUDA=ON
export CMAKE_DISABLE_FIND_PACKAGE_HIP=ON
export CUDA_HOME=""
export ROCM_HOME=""
python3 -m pip config set global.extra-index-url https://download.pytorch.org/whl/cpu
python -m pip install -U pip setuptools wheel

VLLM_TARGET_DEVICE=cpu python -m pip install -e ./integrations/vllm_plugin/

VLLM_TARGET_DEVICE=tt TTXLA_LOGGER_LEVEL=DEBUG \
  vllm serve TinyLlama/TinyLlama-1.1B-Chat-v1.0 \
    --max-model-len 2048 \
    --max-num-batched-tokens 2048 \
    --max-num-seqs 1 \
    --no-enable-prefix-caching \
    --additional-config "{\"enable_const_eval\": \"False\", \"min_context_len\": 32}"

## releases/v0.10.1
##VLLM_TARGET_DEVICE=cpu python -m pip install -e "vllm @ git+https://github.com/vllm-project/vllm.git@1da94e673c257373280026f75ceb4effac80e892"

## VLLM_TARGET_DEVICE=cpu python -m pip install -e "vllm @ git+https://github.com/vllm-project/vllm.git@4fd9d6a85c00ac0186aa9abbeff73fc2ac6c721e"

cd tt-xla
source venv/activate
pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/
pip install flax transformers

pytest -svv "/tt-xla/tests/runner/test_models.py::test_all_models_torch[qwen_2_5_vl/pytorch-7b_instruct-single_device-full-inference]"

pytest /tt-xla/tests/runner/test_models.py --collect-only -q | grep qwen_2_5_vl/pytorch-7b_instruct

pip install -r /tt-forge/benchmark/tt-xla/requirements.txt
pip install -U qwen-vl-utils==0.0.14
pytest -svv /tt-forge/benchmark/tt-xla/llms.py::test_qwen_2_5_vl_7b

export PYTHONPATH=/tt-forge:$PYTHONPATH
pip install flax transformers
python tt-forge/demos/tt-xla/nlp/pytorch/opt_demo.py
