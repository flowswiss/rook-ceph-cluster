#!/bin/bash

# Rook Ceph Fresh Installation Script
# Deploys complete Rook Ceph stack on new k0s cluster

set -e

NAMESPACE="rook-ceph"
HELM_RELEASE="rook-ceph-cluster"

echo "🚀 Starting Rook Ceph fresh installation..."

# Check if already exists
if kubectl get namespace $NAMESPACE 2>/dev/null; then
    echo "⚠️  Namespace $NAMESPACE already exists!"
    echo "   This may overwrite existing installation."
    read -p "   Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 1: Install CRDs first
echo "📋 Step 1: Installing Rook CRDs..."
kubectl apply -f crds/crds.yaml
echo "✅ CRDs installed"

# Wait for CRDs to be established
echo "⏳ Waiting for CRDs to be established..."
kubectl wait --for condition=established crd/cephclusters.ceph.rook.io --timeout=60s
kubectl wait --for condition=established crd/cephblockpools.ceph.rook.io --timeout=60s
kubectl wait --for condition=established crd/cephfilesystems.ceph.rook.io --timeout=60s
echo "✅ CRDs are ready"

# Step 2: Install complete stack with Helm
echo "🔧 Step 2: Installing Rook Ceph stack with Helm..."
helm upgrade --install $HELM_RELEASE . \
  --namespace $NAMESPACE \
  --create-namespace \
  --wait \
  --timeout=20m

echo "✅ Installation completed!"

# Status check
echo "🔍 Checking installation status..."
echo ""
echo "📊 Pods:"
kubectl get pods -n $NAMESPACE
echo ""
echo "📊 CRDs:"
kubectl get crd | grep ceph.rook.io | wc -l | xargs echo "CRDs installed:"
echo ""
echo "📊 Cluster Resources:"
kubectl get cephcluster,cephblockpool,cephfilesystem -n $NAMESPACE
echo ""
echo "📊 Storage Classes:"
kubectl get storageclass | grep rook

echo ""
echo "🎉 Rook Ceph installation successful!"
echo ""
echo "📌 Next steps:"
echo "   • Wait for cluster: kubectl get cephcluster -n $NAMESPACE -w"
echo "   • Check health: kubectl -n $NAMESPACE exec deploy/rook-ceph-cluster-tools -- ceph status"
echo "   • Use storage: kubectl get storageclass | grep rook"
echo ""
echo "🔧 Management:"
echo "   • Status: helm status $HELM_RELEASE -n $NAMESPACE"
echo "   • Upgrade: helm upgrade $HELM_RELEASE . -n $NAMESPACE"
echo "   • Uninstall: ./uninstall.sh"
