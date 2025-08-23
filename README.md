# 🚀 Rook Ceph Helm Chart für k0s

## Komplette Rook Ceph Installation für k0s Kubernetes

Dieses Helm Chart installiert den **kompletten Rook Ceph Stack** auf frischen k0s Kubernetes-Clustern:

- ✅ **CRDs** (Custom Resource Definitions)
- ✅ **Rook Operator** (rook-ceph-operator)
- ✅ **CSI Driver** (RBD + CephFS)
- ✅ **Ceph Cluster** (3-Node HA)
- ✅ **Storage Classes** (Block + FileSystem)
- ✅ **RBAC** (Alle benötigten Berechtigungen)

## 🎯 Ein-Kommando-Installation

```bash
# Komplette Installation mit automatischem CRD-Management
./deploy.sh

# Oder manuell in 2 Schritten:
kubectl apply -f crds/crds.yaml
helm install rook-ceph-cluster . -n rook-ceph --create-namespace
```

## 📋 Voraussetzungen

- **k0s Kubernetes**: v1.28+ (empfohlen: v1.33+)
- **Helm**: v3.8+
- **Raw Storage**: `/dev/sdb` auf allen Worker Nodes
- **Worker Nodes**: Mindestens 3 Nodes für HA
- **Node Names**: `my-001-bit1`, `my-002-bit1`, `my-003-bit1` (anpassbar)

## 🏗️ Architektur

### **Generierte Kubernetes Ressourcen:**

| Komponente | Beschreibung | Anzahl |
|------------|-------------|--------|
| **CRDs** | Custom Resource Definitions (separat) | 15 |
| **Operator** | Rook Ceph Operator | 1 |
| **ServiceAccounts** | RBAC Service Accounts | 9 |
| **ClusterRoles** | Cluster-Berechtigungen | 3 |
| **CSI Components** | RBD + CephFS Drivers | 4 |
| **Ceph Cluster** | Haupt-Cluster-Ressource | 1 |
| **Storage Pools** | Block + Filesystem Pools | 2 |
| **StorageClasses** | Kubernetes Storage Classes | 2 |
| **Services** | Ceph Services | 2 |
| **ConfigMaps** | CSI Konfiguration | 2 |

### **Ceph Cluster Layout:**

```
┌─────────────────┬─────────────────┬─────────────────┐
│   my-001-bit1   │   my-002-bit1   │   my-003-bit1   │
├─────────────────┼─────────────────┼─────────────────┤
│ MON + MGR + OSD │ MON + MGR + OSD │ MON + OSD       │
│ /dev/sdb        │ /dev/sdb        │ /dev/sdb        │
└─────────────────┴─────────────────┴─────────────────┘
```

## 🚀 Installation

### **Methode 1: Automatisches Script (empfohlen)**

```bash
# Einfache Installation mit CRD-Management
./deploy.sh
```

### **Methode 2: Manuell in 2 Schritten**

```bash
# Schritt 1: CRDs installieren
kubectl apply -f crds/crds.yaml

# Schritt 2: Helm Chart installieren
helm install rook-ceph-cluster . \
  --namespace rook-ceph \
  --create-namespace \
  --wait \
  --timeout=20m

# Status prüfen
helm status rook-ceph-cluster -n rook-ceph
```

### **Methode 3: Mit angepassten Values**

```bash
# CRDs und Chart mit angepassten Values
kubectl apply -f crds/crds.yaml
helm install rook-ceph-cluster . \
  -n rook-ceph \
  --create-namespace \
  -f custom-values.yaml
```

## ⚙️ Konfiguration

### **Wichtige Values in `values.yaml`:**

```yaml
# Operator Konfiguration
operator:
  image:
    tag: v1.17.4
  namespace: rook-ceph

# Ceph Cluster
cephCluster:
  cephVersion:
    image: quay.io/ceph/ceph:v19.2.3
  
  # k0s-spezifischer Storage
  storage:
    deviceFilter: "^sdb"  # Alle /dev/sdb Devices
    nodes:
      - name: my-001-bit1
        devices:
          - name: sdb
      # Weitere Nodes...

  # HA Konfiguration
  mon:
    count: 3  # 3 Monitore für HA
  mgr:
    count: 2  # 2 Manager für HA

# Storage Pools
cephBlockPools:
  - name: replicapool
    spec:
      replicated:
        size: 2  # 2 Replicas bei 3 Nodes

cephFileSystems:
  - name: myfs
    spec:
      metadataPool:
        replicated:
          size: 2
```

## 📊 Nach der Installation

### **Cluster Status prüfen:**

```bash
# Helm Status
helm status rook-ceph-cluster -n rook-ceph

# Ceph Cluster Status
kubectl get cephcluster -n rook-ceph

# Alle Pods
kubectl get pods -n rook-ceph

# Ceph Health (nach ~5-10 Minuten)
kubectl -n rook-ceph exec deploy/rook-ceph-cluster-tools -- ceph status
```

### **Storage Classes verwenden:**

```bash
# Verfügbare Storage Classes
kubectl get storageclass

# Block Storage verwenden
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-rbd-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: rook-ceph-block

# Shared Storage verwenden
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-shared-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  storageClassName: rook-cephfs
```

## 🔧 Management

### **Cluster-Operationen:**

```bash
# Upgrade
helm upgrade rook-ceph-cluster . -n rook-ceph

# Konfiguration anzeigen
helm get values rook-ceph-cluster -n rook-ceph

# Deinstallation (ACHTUNG: Löscht alle Daten!)
helm uninstall rook-ceph-cluster -n rook-ceph
```

### **Ceph-Management:**

```bash
# Ceph Status
kubectl -n rook-ceph exec deploy/rook-ceph-cluster-tools -- ceph status

# OSD Status
kubectl -n rook-ceph exec deploy/rook-ceph-cluster-tools -- ceph osd status

# Pool Information
kubectl -n rook-ceph exec deploy/rook-ceph-cluster-tools -- ceph df
```

## 🛠️ Anpassungen

### **Andere Node-Namen:**

In `values.yaml` unter `cephCluster.storage.nodes` anpassen:

```yaml
storage:
  nodes:
    - name: worker-1
      devices:
        - name: sdb
    - name: worker-2
      devices:
        - name: sdb
```

### **Andere Storage-Devices:**

```yaml
storage:
  deviceFilter: "^nvme"  # Für NVMe SSDs
  nodes:
    - name: my-001-bit1
      devices:
        - name: nvme0n1
```

### **Ressourcen-Limits anpassen:**

```yaml
cephCluster:
  resources:
    osd:
      requests:
        cpu: 1000m
        memory: 4Gi
      limits:
        cpu: 2000m
        memory: 8Gi
```

## ❗ Wichtige Hinweise

- **Daten-Verlust**: Deinstallation löscht alle Ceph-Daten unwiderruflich
- **Storage-Devices**: Müssen roh/unformatiert sein (`/dev/sdb` darf keine Partitionen haben)
- **Network**: Alle Nodes müssen untereinander kommunizieren können
- **Zeit**: Erste Installation kann 10-15 Minuten dauern

## 🔍 Troubleshooting

### **Cluster startet nicht:**

```bash
# Operator Logs
kubectl logs -n rook-ceph deployment/rook-ceph-operator

# CephCluster Status
kubectl describe cephcluster rook-ceph -n rook-ceph
```

### **OSDs werden nicht erstellt:**

```bash
# OSD Logs
kubectl logs -n rook-ceph -l app=rook-ceph-osd-prepare

# Device-Discovery
kubectl logs -n rook-ceph -l app=rook-discover
```

### **Storage Classes funktionieren nicht:**

```bash
# CSI Logs
kubectl logs -n rook-ceph -l app=csi-rbdplugin
kubectl logs -n rook-ceph -l app=csi-cephfsplugin
```

---

**Für Support und weitere Informationen siehe:** [Rook Documentation](https://rook.io/docs/)
