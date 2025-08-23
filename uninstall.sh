#!/bin/bash

# Rook Ceph Uninstall Script
# Cleanly removes Rook Ceph installation

set -e

NAMESPACE="rook-ceph"
HELM_RELEASE="rook-ceph-cluster"

echo "🚨 Rook Ceph Uninstallation - THIS WILL DELETE ALL DATA!"
echo ""
echo "⚠️  WARNING: This will permanently delete:"
echo "   • All Ceph data (PVCs, images, pools)"
echo "   • Rook Operator and components"
echo "   • Storage Classes and PVCs"
echo "   • ALL DATA WILL BE LOST FOREVER!"
echo ""
read -p "Are you ABSOLUTELY SURE? Type 'yes-delete-all-data' to continue: " -r
if [[ $REPLY != "yes-delete-all-data" ]]; then
    echo "❌ Uninstallation cancelled"
    exit 1
fi

echo ""
echo "🔄 Starting Rook Ceph uninstallation..."

# Step 1: Delete all PVCs first (to trigger cleanup)
echo "📋 Step 1: Deleting all PVCs using Rook storage classes..."
kubectl get pvc --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.storageClassName | test("rook-ceph")) | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read namespace pvc; do
    echo "  Deleting PVC: $pvc in namespace: $namespace"
    kubectl delete pvc $pvc -n $namespace --timeout=60s || echo "    Failed to delete $pvc"
  done

# Step 2: Delete Helm release
echo "📋 Step 2: Uninstalling Helm release..."
if helm list -n $NAMESPACE | grep -q $HELM_RELEASE; then
    helm uninstall $HELM_RELEASE -n $NAMESPACE --timeout=10m || echo "Helm uninstall failed, continuing..."
else
    echo "  No Helm release found"
fi

# Step 3: Force delete remaining Ceph resources
echo "📋 Step 3: Force deleting remaining Ceph resources..."
kubectl delete cephcluster --all -n $NAMESPACE --timeout=300s || echo "CephCluster deletion timeout"
kubectl delete cephblockpool --all -n $NAMESPACE --timeout=60s || echo "CephBlockPool deletion timeout"
kubectl delete cephfilesystem --all -n $NAMESPACE --timeout=60s || echo "CephFilesystem deletion timeout"

# Step 4: Clean up OSD devices (dangerous!)
echo "📋 Step 4: Cleaning up OSD prepare jobs..."
kubectl delete job -n $NAMESPACE -l app=rook-ceph-osd-prepare --timeout=60s || echo "OSD prepare job cleanup failed"

# Step 5: Remove finalizers if stuck
echo "📋 Step 5: Removing finalizers from stuck resources..."
kubectl get cephcluster -n $NAMESPACE -o name | xargs -I {} kubectl patch {} -n $NAMESPACE --type merge -p '{"metadata":{"finalizers":[]}}' || echo "No CephClusters to patch"

# Step 6: Delete namespace
echo "📋 Step 6: Deleting namespace..."
kubectl delete namespace $NAMESPACE --timeout=300s || echo "Namespace deletion timeout"

# Step 7: Delete CRDs
echo "📋 Step 7: Deleting Rook CRDs..."
kubectl delete -f crds/crds.yaml || echo "CRDs deletion failed"

# Step 8: Manual cleanup hints
echo ""
echo "📋 Step 8: Manual cleanup required on nodes:"
echo ""
echo "🔧 Run this on each node to clean storage devices:"
echo "   sudo wipefs -a /dev/sdb"
echo "   sudo rm -rf /var/lib/rook"
echo "   sudo rm -rf /var/lib/k0s/kubelet/plugins/rook-ceph.rbd.csi.ceph.com"
echo "   sudo rm -rf /var/lib/k0s/kubelet/plugins/rook-ceph.cephfs.csi.ceph.com"
echo ""
echo "🎉 Rook Ceph uninstallation completed!"
echo ""
echo "⚠️  Remember to clean storage devices on all nodes manually!"
