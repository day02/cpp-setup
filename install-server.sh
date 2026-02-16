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
source ~/.bash_aliases

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

# On Worker
BK_VERSION=$(curl -s https://api.github.com/repos/moby/buildkit/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
wget https://github.com/moby/buildkit/releases/download/v${BK_VERSION}/buildkit-v${BK_VERSION}.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf buildkit-v${BK_VERSION}.linux-amd64.tar.gz

sudo nerdctl -n k8s.io build -t vllm-tt:dev -f server/vllm-tt/Dockerfile server/vllm-tt

## Copy the images
docker commit llama_test llama-metal-snap:v1
docker save -o llama_image_backup.tar llama-metal-snap:v1

sudo nerdctl -n k8s.io load -i llama_image_backup.tar
sudo nerdctl -n k8s.io images | grep llama
sudo nerdctl -n k8s.io tag llama-metal-snap:v1 vllm-tt:dev
sudo nerdctl -n k8s.io images | grep vllm-tt

sudo hostnamectl set-hostname worker7
sudo swapoff -a
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | \
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubeadm kubelet

ON MASTER -> sudo kubeadm token create --print-join-command -> run the output on WORKER



#Create partition on workers
sudo lvcreate -l +100%FREE -n models_vol ubuntu-vg
sudo mkfs.ext4 /dev/ubuntu-vg/models_vol
sudo mkdir -p /opt/foundry
sudo mount /dev/ubuntu-vg/models_vol /opt/foundry
sudo echo '/dev/ubuntu-vg/models_vol /opt/foundry ext4 defaults 0 2' | sudo tee -a /etc/fstab

sudo chown tuadmin:tuadmin /opt/foundry/
mkdir -p /opt/foundry/data/slice0
mkdir -p /opt/foundry/data/slice1
sudo reboot


## HELM manual apply
echo "=== 1) Confirm worker10 labels/state ==="
sudo kubectl get nodes
sudo kubectl get node worker10 --show-labels

echo "=== 2) Ensure worker10 has the testing label ==="
sudo kubectl label node worker10 foundry.tt/has-tt-for-testing=true --overwrite

echo "=== 3) Ensure worker10 does NOT have the prod TT label ==="
sudo kubectl label node worker10 foundry.tt/has-tt- || true

echo "=== 4) Ensure worker10 is schedulable ==="
sudo kubectl uncordon worker10 || true

echo "=== 5) Verify only worker10 has the testing label ==="
sudo kubectl get nodes -l foundry.tt/has-tt-for-testing=true --show-labels

echo "=== 10) Render device plugin manifests ==="
helm template foundry . \
  --show-only templates/infra/tt-device-plugin-configmaps.yaml \
  --show-only templates/infra/tt-device-plugin.yaml \
  > worker10-device-plugin.yaml

echo "=== 11) Inspect rendered device plugin ==="
grep -nE 'worker10|has-tt-for-testing|foundry-device-plugin|device-plugin-tt-config' worker10-device-plugin.yaml || true
cat worker10-device-plugin.yaml

echo "=== 12) Dry-run device plugin apply ==="
sudo kubectl apply --dry-run=client -f worker10-device-plugin.yaml

echo "=== 13) Apply device plugin ==="
sudo kubectl apply -f worker10-device-plugin.yaml

echo "=== 14) Verify device plugin DaemonSet ==="
sudo kubectl -n kube-system get ds
sudo kubectl -n kube-system get pods -o wide | grep -E 'foundry-device-plugin-tt-worker10|device-plugin' || true
sudo kubectl -n kube-system logs daemonset/foundry-device-plugin-tt-worker10 || true

echo "=== 15) Check node resource advertisement ==="
sudo kubectl describe node worker10 | grep -A5 -B2 'foundry.tt/' || true

echo "=== 16) Render local PV manifests ==="
helm template foundry . \
  --show-only templates/infra/local-pvs.yaml \
  > worker10-local-pvs.yaml

echo "=== 17) Inspect rendered local PVs ==="
grep -nE 'worker10|foundry-local-pv|local-storage|slice0|slice1|path:' worker10-local-pvs.yaml || true
cat worker10-local-pvs.yaml

echo "=== 18) IMPORTANT: verify PV paths and create those directories on worker10 ==="
echo "Check the path lines in worker10-local-pvs.yaml."
echo "Then SSH to worker10 and create them if needed."

echo "Example only:"
cat <<'EOF'
ssh worker10
sudo mkdir -p /path/from/rendered/pv/slice0
sudo mkdir -p /path/from/rendered/pv/slice1
exit
EOF

read -p "Press Enter after creating the required directories on worker10..."

echo "=== 19) Dry-run local PV apply ==="
sudo kubectl apply --dry-run=client -f worker10-local-pvs.yaml

echo "=== 20) Apply local PVs ==="
sudo kubectl apply -f worker10-local-pvs.yaml

echo "=== 21) Verify worker10 PVs exist ==="
sudo kubectl get pv | grep worker10 || true

echo "=== 22) Render model manifests ==="
helm template foundry . \
  --show-only templates/vllm/headless-services.yaml \
  --show-only templates/vllm/services.yaml \
  --show-only templates/vllm/statefulsets.yaml \
  > worker10-model.yaml

echo "=== 23) Inspect rendered model ==="
grep -nE 'foundry-qwen-image-edit-2509-multiple-images|worker10|has-tt-for-testing|tt-slice|local-storage' worker10-model.yaml || true
cat worker10-model.yaml

echo "=== 24) Dry-run model apply ==="
sudo kubectl apply --dry-run=client -f worker10-model.yaml

echo "=== 25) Apply model ==="
sudo kubectl apply -f worker10-model.yaml

echo "=== 26) Watch PVCs and pods ==="
sudo kubectl -n foundry get pvc
sudo kubectl -n foundry get pods -o wide

echo "=== 27) Detailed checks if still pending ==="
echo "PVCs:"
sudo kubectl -n foundry describe pvc cache-root-foundry-qwen-image-edit-2509-multiple-images-0 || true
sudo kubectl -n foundry describe pvc cache-root-foundry-qwen-image-edit-2509-multiple-images-1 || true

echo "Pods:"
sudo kubectl -n foundry get pods -o wide | grep foundry-qwen-image-edit-2509-multiple-images || true

echo "=== 28) Final verification ==="
echo "Device plugin:"
sudo kubectl -n kube-system get ds foundry-device-plugin-tt-worker10 || true
sudo kubectl -n kube-system get pods -o wide | grep foundry-device-plugin-tt-worker10 || true

echo "Node resource:"
sudo kubectl describe node worker10 | grep -A5 -B2 'foundry.tt/' || true

echo "PVs:"
sudo kubectl get pv | grep worker10 || true

echo "PVCs:"
sudo kubectl -n foundry get pvc | grep foundry-qwen-image-edit-2509-multiple-images || true

echo "Model pods:"
sudo kubectl -n foundry get pods -o wide | grep foundry-qwen-image-edit-2509-multiple-images || true

echo "Services:"
sudo kubectl -n foundry get svc | grep foundry-qwen-image-edit-2509-multiple-images || true

echo "=== Done ==="
