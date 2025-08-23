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

# Install complete stack
echo "🔧 Installing complete Rook Ceph stack..."
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
kubectl get crd | grep ceph.rook.io
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
echo "   • Uninstall: helm uninstall $HELM_RELEASE -n $NAMESPACE"
