#!/bin/bash
# Tools and dependencies setup for Rocky Linux 9

set -euo pipefail
export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

echo "➡ Tools and dependencies installation"
dnf -y update

# Base tools
dnf install -y \
    epel-release \
    net-tools iproute iputils bind-utils curl wget \
    htop tcpdump traceroute nmap openssh-server vim nano tmux \
    unzip lsof whois bash-completion ca-certificates gnupg2 jq \
    yum-utils device-mapper-persistent-data lvm2

# Stop & disable firewalld
systemctl stop firewalld.service || true
systemctl disable firewalld.service || true

# Docker installation
echo "➡ Docker installation..."
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker vagrant

# Kind installation
echo "➡ Kind installation..."
curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
chmod +x /usr/local/bin/kind

# Helm installation
echo "➡ Helm installation..."
dnf install -y git
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
/usr/local/bin/helm version

# Kubectl installation
echo "➡ Kubectl installation..."
cat >/etc/yum.repos.d/kubernetes.repo <<'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

dnf install -y kubectl --disableexcludes=kubernetes

# Kubectl autocompletion
echo 'source <(kubectl completion bash)' | tee -a /root/.bashrc /home/vagrant/.bashrc > /dev/null

# CNPG kubectl plugin installation
echo "➡ CNPG kubectl plugin installation..."
curl -sSfL \
  https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
  sh -s -- -b /usr/local/bin

# CNPG kubectl plugin autocompletion
cat >/usr/local/bin/kubectl_complete-cnpg <<'EOF'
#!/usr/bin/env sh
kubectl cnpg __complete "$@"
EOF
chmod +x /usr/local/bin/kubectl_complete-cnpg

# Kind cluster creation
echo "➡ Kind cluster creation..."
kind create cluster --verbosity 9 --config /vagrant/conf/kind-cluster-config.yaml

# kubeconfig for vagrant user
mkdir -p /home/vagrant/.kube
cp /root/.kube/config /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# MinIO setup for backup
echo "➡ MinIO setup..."
docker run -p 9000:9000 -p 9001:9001 \
           -e MINIO_ROOT_USER=admin \
           -e MINIO_ROOT_PASSWORD=password \
           -d \
           --network kind \
           --name minio \
           minio/minio server /data \
           --console-address ":9001"

# MinIO secrets
kubectl create secret generic minio-creds \
  --from-literal=MINIO_ACCESS_KEY=admin \
  --from-literal=MINIO_SECRET_KEY=password

# PostgreSQL client 16 installation
echo "➡ PostgreSQL client installation..."
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
dnf -qy module disable postgresql
dnf install -y postgresql16

# Prometheus / Grafana
echo "➡ Prometheus / Grafana installation..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus-community prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml

# Install cert-manager
echo "➡ cert-manager installation..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Install cmctl
echo "➡ cmctl installation..."
curl -fsSL -o /usr/local/bin/cmctl https://github.com/cert-manager/cmctl/releases/latest/download/cmctl_linux_amd64
chmod +x /usr/local/bin/cmctl

echo "✅ Tools installation finished"