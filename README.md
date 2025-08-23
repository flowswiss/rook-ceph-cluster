# Rook Ceph Cluster Helm Chart

Production-ready Helm Chart for Rook Ceph Storage on k0s Kubernetes.

## Overview

This Helm Chart deploys a complete Rook Ceph cluster with:
- **Rook Operator** v1.17.4 (latest version)
- **Ceph Storage** v19.2.3 (Squid - latest LTS)
- **k0s-optimized configuration**
- **Block & Filesystem Storage Classes**

## Current Configuration

**Your cluster specifications:**
- **Nodes**: my-001-bit1, my-002-bit1, my-003-bit1
- **Replica Size**: 2 (optimized for 3-node setup)
- **Storage Devices**: `/dev/sdb` on all nodes
- **CNI**: kuberouter
- **k0s Version**: 1.33.3+k0s.0

## Installation

### Prerequisites
```bash
# k0s cluster must be running
sudo k0s status

# Helm must be installed (v3.8+)
helm version

# Create k0s-specific directories (on all nodes)
sudo mkdir -p /var/lib/k0s/kubelet/plugins_registry /var/lib/k0s/kubelet/pods
```

### Deploy
```bash
# Install chart (automatically creates RBAC for k0s)
helm install rook-ceph-cluster . -f values.yaml --namespace rook-ceph --create-namespace

# Check status
kubectl get cephcluster rook-ceph -n rook-ceph
```

### Upgrade
```bash
# Modify configuration
vim values.yaml

# Apply upgrade  
helm upgrade rook-ceph-cluster . -f values.yaml --namespace rook-ceph
```

## Configuration

### Important Parameters in `values.yaml`

```yaml
# Rook Operator
operator:
  image:
    tag: v1.17.4
  env:
    ROOK_CSI_KUBELET_DIR_PATH: "/var/lib/k0s/kubelet"  # k0s-specific!

# Ceph Version
cephCluster:
  cephVersion:
    image: quay.io/ceph/ceph:v19.2.3

# Storage
cephBlockPools:
  - name: replicapool
    spec:
      replicated:
        size: 2  # Adjust based on nodes

# Filesystem  
cephFileSystems:
  - name: myfs
    spec:
      metadataPool:
        replicated:
          size: 2
```

### Node-specific Configuration

Adapted for your environment:
```yaml
placement:
  all:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                  - my-001-bit1
                  - my-002-bit1  
                  - my-003-bit1
```

## k0s-specific Configuration

This chart is specifically optimized for k0s and automatically fixes the following issues:

### RBAC Permissions
- ✅ **EndpointSlice Permissions**: Automatically created for Rook v1.17+
- ✅ **ClusterRole**: `rook-ceph-system-endpointslice` 
- ✅ **ClusterRoleBinding**: Links ServiceAccount with permissions

### CSI Plugin Paths
- ✅ **Kubelet Directory**: `/var/lib/k0s/kubelet` (instead of standard `/var/lib/kubelet`)
- ✅ **Environment Variable**: `ROOK_CSI_KUBELET_DIR_PATH` correctly set
- ✅ **Host Directories**: Automatic creation on all nodes

## Storage Classes

Available after installation:
- **rook-ceph-block**: RBD Block Storage (ReadWriteOnce)
- **rook-cephfs**: CephFS Shared Storage (ReadWriteMany)

```bash
# Check storage classes
kubectl get storageclass
```

## Monitoring & Maintenance

### Cluster Health
```bash
# Ceph status
kubectl -n rook-ceph exec deployment/rook-ceph-tools -- ceph status

# Cluster overview
kubectl get cephcluster rook-ceph -n rook-ceph -o wide
```

### Pod Status
```bash
# All Rook pods
kubectl get pods -n rook-ceph

# Critical services only
kubectl get pods -n rook-ceph | grep -E "(operator|mon|mgr|osd)"
```

## Troubleshooting

### Common Issues

**CSI plugins crashing:**
```bash
# Create k0s-specific directories (on all nodes)
sudo mkdir -p /var/lib/k0s/kubelet/plugins_registry /var/lib/k0s/kubelet/pods

# Restart CSI plugins
kubectl rollout restart daemonset/csi-cephfsplugin -n rook-ceph
kubectl rollout restart daemonset/csi-rbdplugin -n rook-ceph
```

**EndpointSlice permissions missing:**
```bash
# Check if RBAC exists
kubectl get clusterrole rook-ceph-system-endpointslice

# If not: reinstall chart or upgrade
helm upgrade rook-ceph-cluster . -f values.yaml --namespace rook-ceph
```

**OSD not available:**
```bash
# Check device status
kubectl -n rook-ceph exec deployment/rook-ceph-tools -- ceph osd status
```

### Collecting Logs
```bash
# Operator logs
kubectl logs -n rook-ceph deployment/rook-ceph-operator

# Ceph tools for debugging
kubectl -n rook-ceph exec -it deployment/rook-ceph-tools -- bash
```

## Updates

### Rook Version Update
1. Set new version in `values.yaml`
2. Run `helm upgrade`  
3. Rolling update automatic

### Ceph Version Update
1. Set new Ceph image in `values.yaml`
2. Run `helm upgrade`
3. Ceph rolling update (15-30 min)

## Storage Usage Examples

### Block Storage (RBD)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: rook-ceph-block
  resources:
    requests:
      storage: 10Gi
```

### Shared Storage (CephFS)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-shared-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: rook-cephfs
  resources:
    requests:
      storage: 50Gi
```

## Performance Tuning

### For Small Clusters (3 nodes)
```yaml
cephCluster:
  # Optimal replica size for 3 nodes
  cephBlockPools:
    - spec:
        replicated:
          size: 2  # Recommended for 3-node setup
  
  # Resource limits
  resources:
    osd:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 1000m
        memory: 4Gi
```

### For Production Workloads
```yaml
cephCluster:
  # Higher replica size for production
  cephBlockPools:
    - spec:
        replicated:
          size: 3  # Full redundancy
  
  # Performance settings
  disruptionManagement:
    managePodBudgets: true
    osdMaintenanceTimeout: 30
```

## Backup and Recovery

### Cluster Backup
```bash
# Backup cluster configuration
kubectl get cephcluster rook-ceph -n rook-ceph -o yaml > ceph-cluster-backup.yaml

# Backup storage classes
kubectl get storageclass -o yaml > storage-classes-backup.yaml
```

### Disaster Recovery
```bash
# In case of cluster failure, restore from backup
kubectl apply -f ceph-cluster-backup.yaml
kubectl apply -f storage-classes-backup.yaml
```

## Security Considerations

### Network Security
```yaml
cephCluster:
  network:
    connections:
      encryption:
        enabled: true  # Enable encryption in transit
      compression:
        enabled: false  # Disable for better performance
```

### RBAC Security
```yaml
rbac:
  create: true  # Always enable RBAC
  
# The chart automatically creates minimal required permissions
# Additional permissions should be added separately if needed
```

## Support

- **Rook Documentation**: https://rook.io/docs/
- **k0s Documentation**: https://docs.k0sproject.io/
- **Ceph Documentation**: https://docs.ceph.com/
- **Helm Documentation**: https://helm.sh/docs/

## Contributing

### Chart Development
```bash
# Validate chart syntax
helm lint .

# Test template rendering
helm template test-release . -f values.yaml --dry-run

# Debug specific template
helm template test-release . -f values.yaml -s templates/cephcluster.yaml
```

### Testing
```bash
# Install in test namespace
helm install test-rook . -f values.yaml --namespace rook-test --create-namespace

# Cleanup test installation
helm uninstall test-rook -n rook-test
kubectl delete namespace rook-test
```

---

## Chart Information

**Version**: 1.17.4  
**App Version**: v19.2.3  
**Tested with**: k0s v1.33.3+k0s.0  
**Maintained by**: masterguru  

## License

This Helm chart is licensed under Apache-2.0.

## Changelog

### v1.17.4
- Updated to Rook v1.17.4 and Ceph v19.2.3
- Added k0s-specific configurations
- Fixed EndpointSlice RBAC permissions
- Optimized for 3-node clusters
- Added comprehensive documentation

---

*For previous versions and detailed changelog, see the releases page.*
