# (Solution 1)  
## Mount the NFS share directly inside the prometheus POD using ***nfs***
The easiest solution is to mount the NFS share inside the POD.
```
   nfs  <Object>
     nfs represents an NFS mount on the host that shares a pod's lifetime More
     info: https://kubernetes.io/docs/concepts/storage/volumes#nfs
```
specifically we specify the NFS server FQDN and the shared folder we mount inside the pod:
```
        - name: prometheus-storage-volume
          nfs:
            server: centos8s-server.singleton.net
            path: /mnt/nfs_shares/cluster_nfs/Prometheus
```
***deployment-nfs-mount.yaml***
```
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
              memory: 2Gi
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
          nfs:
            server: centos8s-server.singleton.net
            path: /mnt/nfs_shares/cluster_nfs/Prometheus
```
We now deploy prometheus and verify the content of the NFS share inside the POD.  
```
# Create the monitoring namespace
$ kubectl apply -f namespace.yaml
namespace/monitoring created

# Create the configmap
$ kubectl apply -f config_map.yaml
configmap/prometheus-server-conf created

# Deploy the prometheus POD
$ kubectl apply -f deployment-nfs-mount.yaml
NAME                                     READY   STATUS    RESTARTS   AGE
prometheus-deployment-5fdcd466b4-4p8kt   1/1     Running   0          34m

# Verify the POD Running status
$ kubectl get pods -n monitoring
NAME                                     READY   STATUS    RESTARTS   AGE
prometheus-deployment-5fdcd466b4-4p8kt   1/1     Running   0          34m

# connect to the POD and verify the mount point exists
$ kubectl  exec  prometheus-deployment-5fdcd466b4-4p8kt  -n monitoring -it  -- /bin/sh
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
drwxr-xr-x    2 nobody   nobody          22 Mar  8 09:39 wal
```