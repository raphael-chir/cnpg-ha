#!/bin/bash
# Tools and dependencies setup

set -e

echo "➡ Tools and dependencies installation"
apt-get update && apt-get upgrade -y

# Tools and dependencies installation
apt-get install -y \
    net-tools iproute2 iputils-ping dnsutils curl wget \
    htop tcpdump traceroute nmap openssh-server vim nano tmux \
    unzip lsof whois bash-completion ca-certificates gnupg apt-transport-https gpg jq

# Docker installation
echo "➡ Docker installation..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker vagrant

# Kind installation
echo "➡ Kind installation"
KIND_ARCH=$(uname -m)
[ "$KIND_ARCH" = "x86_64" ] && KIND_URL="https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64"
[ "$KIND_ARCH" = "aarch64" ] && KIND_URL="https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-arm64"
curl -Lo /usr/local/bin/kind $KIND_URL
chmod +x /usr/local/bin/kind

# Helm installation
echo "➡ Helm installation..."
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor -o /usr/share/keyrings/helm.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update
apt-get install -y helm

# Kubectl installation
echo "➡ Kubectl installation ..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl

# Kubectl autocompletion
echo 'source <(kubectl completion bash)' | tee -a /root/.bashrc /home/vagrant/.bashrc > /dev/null

# Kind cluster creation
kind create cluster --verbosity 9 --config /vagrant/conf/kind-cluster-config.yaml

# kube config for vagrant user
mkdir -p /home/vagrant/.kube
cp /root/.kube/config /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# cnpg kubectl plugin installation
curl -sSfL \
  https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
  sudo sh -s -- -b /usr/local/bin

# Minio Setup for backup
docker run -p 9000:9000 -p 9001:9001 \
           -e MINIO_ROOT_USER=admin \
           -e MINIO_ROOT_PASSWORD=password \
           -d \
           --network kind\
           --name minio \
           minio/minio server /data \
           --console-address ":9001"

# MinIO secrets
kubectl create secret generic minio-creds \
  --from-literal=MINIO_ACCESS_KEY=admin \
  --from-literal=MINIO_SECRET_KEY=password

# PSQL installation
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | gpg --dearmor | sudo tee /usr/share/keyrings/postgresql.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" \
  | sudo tee /etc/apt/sources.list.d/pgdg.list > /dev/null
apt-get update
apt-get install -y postgresql-client-16

# Prometheus / Grafana
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm upgrade --install \
  -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml \
  prometheus-community \
  prometheus-community/kube-prometheus-stack

echo " Tools installation finished"
