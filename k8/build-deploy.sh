#!/bin/bash
set -euo pipefail

# Saltea Admin Build & Deploy
# Builds the saltea-admin image and deploys to K8s.
# Shares the same database as dna-admin.

REGISTRY_HOST="${REGISTRY_HOST:-smokey01}"
REGISTRY_PORT="32000"
IMAGE_NAME="saltea-admin"
TAG="${TAG:-latest}"
KUBECTL_NODE="${KUBECTL_NODE:-smokey01}"
KUBECTL="ssh ${KUBECTL_NODE} sudo microk8s kubectl"

echo "=== Building Saltea Admin ==="

# Step 1: Sync source to Pi
rsync -avz --exclude .git --exclude tmp --exclude log \
  ./ "${REGISTRY_HOST}:~/build/${IMAGE_NAME}/"

# Step 2: Build & push
ssh "${REGISTRY_HOST}" bash -c "'
  cd ~/build/${IMAGE_NAME} &&
  sudo docker build -t localhost:${REGISTRY_PORT}/${IMAGE_NAME}:${TAG} . &&
  sudo docker push localhost:${REGISTRY_PORT}/${IMAGE_NAME}:${TAG}
'"

echo "=== Deploying Saltea Admin ==="

# Step 3: Apply K8s manifests
${KUBECTL} apply -f - < k8/saltea-admin-secrets.yml
${KUBECTL} apply -f - < k8/saltea-admin-service.yml
${KUBECTL} apply -f - < k8/saltea-admin-deployment.yml
${KUBECTL} apply -f - < k8/saltea-admin-ingress.yml

# Step 4: Rollout restart & verify
${KUBECTL} rollout restart deployment/saltea-admin -n default
${KUBECTL} rollout status deployment/saltea-admin -n default --timeout=120s

echo ""
echo "=== Saltea Admin Deployed ==="
${KUBECTL} get pods -n default -l app=saltea-admin -o wide
echo ""
echo "URL: https://saltea-admin.instinct.is"
echo ""
echo "To run Saltea seeds:"
echo "  ${KUBECTL} exec deployment/saltea-admin -n default -- rake db:seed:011_saltea_store"
