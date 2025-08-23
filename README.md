# Rook Ceph on k0s Kubernetes Cluster

This repository contains Helm values files and documentation for deploying Rook Ceph storage on a k0s-based Kubernetes cluster.

## Prerequisites

- k0s Kubernetes cluster (v1.33.3+k0s.0 or later)
- 3 nodes with dedicated storage devices for Ceph OSDs
- Helm 3.x installed
- kubectl configured to access your cluster

## Cluster Architecture

The deployment is configured for a 3-node cluster with the following specifications:

- **Nodes**:
  - my-001-bit1 (10.90.0.141) - Controller + Worker
  - my-002-bit1 (10.90.0.142) - Controller + Worker
  - my-003-bit1 (10.90.0.143) - Controller + Worker

- **Storage Configuration**:
  - Each node has `/dev/sdb` dedicated for Ceph storage
  - Replication factor: 2
  - Failure domain: host

## Important k0s-Specific Configuration

k0s uses a different kubelet path than standard Kubernetes distributions. This deployment is configured with:
- **Kubelet Path**: `/var/lib/k0s/kubelet` (instead of `/var/lib/kubelet`)

This is already configured in the provided values files.

## Installation Guide

### 1. Add Rook Helm Repository

```bash
helm repo add rook-release https://charts.rook.io/release
helm repo update
```

### 2. Install Rook Ceph Operator

Deploy the Rook Ceph operator using the provided values file:

```bash
helm install --create-namespace --namespace rook-ceph \
  rook-ceph rook-release/rook-ceph \
  -f rook-ceph-operator-values.yaml
```

Wait for the operator to be ready:

```bash
kubectl -n rook-ceph wait --for=condition=ready pod \
  -l app=rook-ceph-operator --timeout=300s
```

### 3. Install Ceph Cluster

Deploy the Ceph cluster using the cluster values file:

```bash
helm install --namespace rook-ceph \
  rook-ceph-cluster rook-release/rook-ceph-cluster \
  -f rook-ceph-cluster-values.yaml
```

### 4. Verify Installation

Check cluster health:

```bash
# Check if all pods are running
kubectl -n rook-ceph get pods

# Check Ceph cluster status
kubectl -n rook-ceph get cephcluster

# Check storage classes
kubectl get storageclass
```

## Configuration Files

### rook-ceph-operator-values.yaml

Key configurations:
- CSI kubelet path adjusted for k0s
- CSI provisioner replicas: 2
- Enabled drivers: RBD and CephFS
- Security context with non-root user (2016)
- Node failure toleration: 5 seconds

### rook-ceph-cluster-values.yaml

Key configurations:
- Ceph version: v19.2.3
- Mon count: 3
- Mgr count: 2
- OSD devices: `/dev/sdb` on each node
- Block pool replication: 2
- CephFS metadata and data pool replication: 2
- Dashboard enabled on port 8080 (no SSL)

## Storage Classes

The deployment creates two storage classes:

1. **rook-ceph-block** - For RBD block storage
   - Provisioner: `rook-ceph.rbd.csi.ceph.com`
   - Pool: `replicapool`
   - Features: Dynamic provisioning, volume expansion

2. **rook-cephfs** - For CephFS shared filesystem
   - Provisioner: `rook-ceph.cephfs.csi.ceph.com`
   - Filesystem: `myfs`
   - Features: Dynamic provisioning, volume expansion

## Toolbox Access

The Ceph toolbox is enabled for debugging and administration:

```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash
```

Inside the toolbox, you can run Ceph commands:

```bash
ceph status
ceph osd status
ceph df
```

## Monitoring

Dashboard access (if exposed):
- Port: 8080
- SSL: Disabled
- URL Prefix: /

To access the dashboard, you can use port-forwarding:

```bash
kubectl -n rook-ceph port-forward svc/rook-ceph-mgr-dashboard 8080:8080
```

## Upgrade Guide

To upgrade the Rook operator or Ceph cluster:

1. Update the operator:
```bash
helm upgrade --namespace rook-ceph rook-ceph rook-release/rook-ceph \
  -f rook-ceph-operator-values.yaml
```

2. Update the cluster:
```bash
helm upgrade --namespace rook-ceph rook-ceph-cluster \
  rook-release/rook-ceph-cluster -f rook-ceph-cluster-values.yaml
```

## Uninstallation

⚠️ **Warning**: This will delete all data stored in Ceph!

1. Delete the Ceph cluster:
```bash
helm uninstall --namespace rook-ceph rook-ceph-cluster
```

2. Delete the operator:
```bash
helm uninstall --namespace rook-ceph rook-ceph
```

3. Clean up the namespace:
```bash
kubectl delete namespace rook-ceph
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Init or Pending state**
   - Check node resources: `kubectl describe nodes`
   - Check PVC status: `kubectl get pvc -A`

2. **OSDs not coming up**
   - Verify devices are available: `lsblk` on each node
   - Check OSD logs: `kubectl -n rook-ceph logs -l app=rook-ceph-osd`

3. **CSI issues**
   - Verify kubelet path is correct: `/var/lib/k0s/kubelet`
   - Check CSI pods: `kubectl -n rook-ceph get pods | grep csi`

### Useful Commands

```bash
# Check Ceph health from any node
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph health detail

# List all Ceph resources
kubectl -n rook-ceph get all

# Check events for troubleshooting
kubectl -n rook-ceph get events --sort-by='.lastTimestamp'

# View operator logs
kubectl -n rook-ceph logs -l app=rook-ceph-operator -f
```

## Support

For issues specific to:
- Rook: [Rook GitHub Issues](https://github.com/rook/rook/issues)
- k0s: [k0s GitHub Issues](https://github.com/k0sproject/k0s/issues)
- Ceph: [Ceph Documentation](https://docs.ceph.com/)

## License

This configuration is provided as-is for use with Rook Ceph and k0s Kubernetes clusters.