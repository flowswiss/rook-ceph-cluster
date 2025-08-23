#!/bin/bash

# Complete Rook Ceph Deployment Script
# Deploys Operator + Cluster with Helm

set -e

NAMESPACE="rook-ceph"
HELM_RELEASE="rook-ceph-cluster"

echo "🚀 Starting complete Rook Ceph deployment..."

# Schritt 1: Namespace erstellen
echo "📋 Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Schritt 2: Helm Chart installieren (CRDs, Operator, Cluster)
echo "🔧 Installing complete Rook Ceph stack with Helm..."
helm upgrade --install $HELM_RELEASE . \
  --namespace $NAMESPACE \
  --create-namespace \
  --wait \
  --timeout=1200s

echo "✅ Installation completed successfully!"

# Schritt 3: Status prüfen
echo "🔍 Checking deployment status..."

echo "📊 Operator Status:"
kubectl get deployment rook-ceph-operator -n $NAMESPACE

echo ""
echo "📊 CRDs Status:"
kubectl get crd | grep ceph.rook.io | head -5

echo ""
echo "📊 Cluster Status:"
kubectl get cephcluster -n $NAMESPACE

echo ""
echo "📊 Storage Status:"
kubectl get cephblockpool,cephfilesystem -n $NAMESPACE

echo ""
echo "📊 StorageClasses:"
kubectl get storageclass | grep rook

echo ""
echo "🎉 Complete Rook Ceph stack deployed successfully!"
echo ""
echo "📌 Next steps:"
echo "   • Monitor cluster: kubectl get pods -n $NAMESPACE"
echo "   • Check health: kubectl -n $NAMESPACE exec deploy/rook-ceph-cluster-tools -- ceph status"
echo "   • Access dashboard: kubectl -n $NAMESPACE get svc rook-ceph-mgr"
echo ""
echo "💡 Manage with Helm:"
echo "   • Status: helm status $HELM_RELEASE -n $NAMESPACE"
echo "   • Upgrade: helm upgrade $HELM_RELEASE . -n $NAMESPACE"
echo "   • Uninstall: helm uninstall $HELM_RELEASE -n $NAMESPACE"
