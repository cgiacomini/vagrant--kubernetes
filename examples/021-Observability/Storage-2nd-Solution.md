# (Solution 2)  
## Mount the NFS share as a volume inside a persistentVolume using ***nfs*** type.
The second best approach consist in creating a PersistentVolume and a PersistentVolumeClaim
The PersistentVolume uses a class of storage (a storageClass). Each Storage class has a provider which determines which volume plugin is used for provisioning PVs.  
Here we uses **kubernetes.io/nfs** internal plugin shipped with kubernetes.

### Create nfs-storage storageClass
***storage.yaml***: [part 1]
```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: nfs-storageclass
provisioner: kubernetes.io/nfs
reclaimPolicy: Retain
allowVolumeExpansion: true
```
***Note:***  
>***reclamePolicy***
>  * *Retain*: the PV wont be deleted if the PVC is deleted.
>  * *Recycle*: scrub(content deletion) and makes the volume available to be calaimed again
>  * *Delete*: delete the persistentVolume completely when the PVC is deleted.  

>***allowVolumeExpansion***
>  * this allow PVC to be expanded for example by editing it and request more storage capacity.

### Create a Persistent Volume and a Persistent Volume Claim
***storage.yaml*** [part 2]
```
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-pv
  namespace: monitoring
  labels:
    app: prometheus-deployment
spec:
  storageClassName: nfs-storageclass
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: centos8s-server.singleton.net
    path: /mnt/nfs_shares/cluster_nfs/Prometheus
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: monitoring
  labels:
    app: prometheus-deployment
spec:
  storageClassName: nfs-storageclass
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
```
### Create a Prometheus Deployment
***deployment.yaml***
```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-deployment
  namespace: monitoring
  labels:
    app: prometheus-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-server
  template:
    metadata:
      labels:
        app: prometheus-server
    spec:
      serviceAccountName: prometheus
      containers:
        - name: prometheus
          image: prom/prometheus
          args:
            - "--storage.tsdb.retention.time=12h"
            - "--config.file=/etc/prometheus/prometheus.yml"
            - "--storage.tsdb.path=/prometheus/"
          ports:
            - containerPort: 9090
          resources:
            requests:
              cpu: 500m
              memory: 500M
            limits:
              cpu: 1
              memory: 1Gi
          volumeMounts:
            - name: prometheus-config-volume
              mountPath: /etc/prometheus/
            - name: prometheus-storage-volume
              mountPath: /prometheus/
      volumes:
        - name: prometheus-config-volume
          configMap:
            defaultMode: 420
            name: prometheus-server-conf

        - name: prometheus-storage-volume
          persistentVolumeClaim:
            claimName: prometheus-pvc
```

We now deploy prometheus and verify the content of the NFS share inside the POD.
```
# Create the monitoring namespace
$ kubectl apply -f namespace.yaml
namespace/monitoring created

# Create Service Account, Cluster Role and RoleBinding
$ kubectl apply -f cluster_role.yaml
serviceaccount/prometheus created
clusterrole.rbac.authorization.k8s.io/prometheus created
clusterrolebinding.rbac.authorization.k8s.io/prometheus created

# Create storage class, pv and pvc
$ kubectl apply -f storage.yaml
storageclass.storage.k8s.io/nfs-storageclass created
persistentvolume/prometheus-pv created
persistentvolumeclaim/prometheus-pvc created

# Create the configmap
$ kubectl apply -f config_map.yaml
configmap/prometheus-server-conf created

# Deploy prometheus POD
$ kubectl apply -f deployment.yaml
deployment.apps/prometheus-deployment created

# Verify Prometheus POD is running
$ kubectl get pods -n monitoring
NAME                                     READY   STATUS    RESTARTS   AGE
prometheus-deployment-847b77bd49-zptdh   1/1     Running   0          3m32s

# connect to the POD and verify the mount point exists
$ kubectl exec prometheus-deployment-847b77bd49-zptdh -n monitoring -it  -- /bin/sh
/prometheus $
/prometheus $ mount | grep centos8s-server.singleton.net
centos8s-server.singleton.net:/mnt/nfs_shares/cluster_nfs/Prometheus on /prometheus type nfs4 (rw,relatime,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.56.11,local_lock=none,addr=192.168.56.200)

# Verify Prometheus has created the require metrics directory structure
/prometheus $ ls -la /prometheus
total 20
drwxrwxrwx    4 nobody   nobody          70 Mar  8 09:41 .
drwxr-xr-x    1 root     root            63 Mar  8 09:39 ..
drwxr-xr-x    2 nobody   nobody          20 Mar  8 09:49 chunks_head
-rw-r--r--    1 nobody   nobody           0 Mar  8 09:39 lock
-rw-r--r--    1 nobody   nobody       20001 Mar  8 10:14 queries.active
drwxr-xr-x    2 nobody   nobody          22 Mar  8 09:39 wal -n monitoring -it  -- /bin/sh
```
