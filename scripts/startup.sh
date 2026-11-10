#!/bin/bash

usage() {
  echo "
  -u    Github user
  -r    Git repository name
  -c    Cluster
  "
}

# Parsing args
options=':hu:r:c:'
while getopts $options option; do
  case "$option" in
    h) usage; exit;;
    u) GIT_USER=$OPTARG;;
    r) GIT_REPO=$OPTARG;;
    c) CLUSTER=$OPTARG;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2; usage >&2; exit 1;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2; usage >&2; exit 1;;
  esac
done


# Checking arguments
if [[ -z "${GITHUB_TOKEN}" ]]; then
    echo "Not github token for bootstraping flux."
    usage
    exit -1
fi

if [[ -z $GIT_USER ]]; then
    echo "Missing github user"
    usage
    exit -1
fi

if [[ -z $GIT_REPO ]]; then
    echo "Missing repository name"
    usage
    exit -1
fi

if [[ -z $CLUSTER ]]; then
    echo "Missing cluster name"
    usage
    exit -1
fi

# Install privileged packages
sudo ./install.sh

# Install kubectl
echo "Installing kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
mkdir -p "$HOME/.local/bin"
install -m 0755 kubectl "$HOME/.local/bin/kubectl"
rm -r kubectl

if ! command -v kubectl; then
    echo "Kubectl not installed correctly"
    exit -1
fi
echo "Kubectl installed"

# Create kind cluster
echo "Creating kind cluster"
if kind get clusters | grep -Fxq $CLUSTER; then
    echo "cluster already exists"
else
    kind create cluster --config cluster.yaml
fi
echo "Kind cluster created"

# Install flux
echo "Installing flux"
curl -s https://fluxcd.io/install.sh | bash
echo "Flux installed"

if ! command -v flux; then
    echo "Flux not installed correctly"
    exit -1
fi

# Bootstrap flux
echo "Bootstraping flux in $CLUSTER cluster"
flux bootstrap github \
  --token-auth \
  --owner=$GIT_USER \
  --repository=$GIT_REPO \
  --branch=main \
  --path=../clusters/$CLUSTER \
  --personal
echo "Bootstraped flux in $CLUSTER cluster"
