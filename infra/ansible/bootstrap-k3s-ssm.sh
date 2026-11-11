#!/usr/bin/env bash
set -euo pipefail

: "${K3S_REGION:?Set the project AWS region}"
: "${K3S_NODE_IP:?Set this node private IP}"
: "${K3S_NODE_MODE:?Set server or agent}"
case "$K3S_NODE_MODE" in
  server) unit=k3s ;;
  agent) unit=k3s-agent; : "${K3S_SERVER_IP:?Set the control plane private IP}" ;;
  *) echo "Expected server or agent" >&2; exit 2 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl unzip
if ! command -v aws >/dev/null 2>&1; then
  install_dir=$(mktemp -d)
  (
    trap 'rm -rf "$install_dir"' EXIT
    cd "$install_dir"
    curl -fsSL --retry 3 https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
    unzip -q awscliv2.zip
    ./aws/install
  )
fi
install -d -m 0700 /etc/rancher/k3s
umask 077
token_tmp=$(mktemp /etc/rancher/k3s/join-token.XXXXXXXX)
trap 'rm -f "$token_tmp"' EXIT
aws ssm get-parameter --region "$K3S_REGION" \
  --name /devops-image-processing/k3s/join-token --with-decryption \
  --query Parameter.Value --output text > "$token_tmp"
test -s "$token_tmp"
install -m 0600 "$token_tmp" /etc/rancher/k3s/join-token
{
  printf 'node-ip: "%s"\n' "$K3S_NODE_IP"
  printf 'token-file: "/etc/rancher/k3s/join-token"\n'
  if [ "$K3S_NODE_MODE" = agent ]; then
    printf 'server: "https://%s:6443"\n' "$K3S_SERVER_IP"
  fi
} > /etc/rancher/k3s/config.yaml

curl -fsSL --retry 3 https://get.k3s.io -o /usr/local/sbin/install-k3s
INSTALL_K3S_VERSION='v1.35.10+k3s1' sh /usr/local/sbin/install-k3s "$K3S_NODE_MODE"
systemctl is-active "$unit"
k3s --version
