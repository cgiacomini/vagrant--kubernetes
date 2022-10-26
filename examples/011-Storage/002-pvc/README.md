# Persistent Volume Claims
* Is used to define what type of storage is needed. 
* It talk to the available backend storage provedir to claim available volumes of the storge type.

# Example 
***persistent-volume.yaml***
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
```

## Deploy persistent-volume

* This configuration file specifies that the volume is at /mnt/data on the cluster's Node. 
* The configuration also specifies a size of 10 gibibytes and an access mode of ReadWriteOnce, which means the volume can be mounted as read-write by a single Node. 
* It defines the ***StorageClass*** name ***manual*** for the PersistentVolume, which will be used to bind PersistentVolumeClaim requests to this PersistentVolume.

StorageClassName
* A PV can have a class, which is specified by setting the storageClassName attribute to the name of a StorageClass. 
* A PV of a particular class can only be bound to PVCs requesting that class. 
* A PV with no storageClassName has no class and can only be bound to PVCs that request no particular class.

```
$ kubectl create -f persistent-volume.yaml
persistentvolume/task-pv-volume created

$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
task-pv-volume   10Gi       RWO            Retain           Available           manual                  103s

```

## Deploy persistent volume claim

* Pods use PersistentVolumeClaims to request physical storage.
* Here is a PersistentVolumeClaim that requests a volume of at least three gibibytes that can provide read-write access for at least one Node.

***persistent-volume-claim.yaml***
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
```

```
$ kubectl create -f persistent-volume-claim.yaml
persistentvolumeclaim/task-pv-claim created

$ kubectl get pv -o wide
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                   STORAGECLASS   REASON   AGE   VOLUMEMODE
task-pv-volume   10Gi       RWO            Retain           Bound    default/task-pv-claim   manual                  13m   Filesystem

$ kubectl get pvc -o wide
NAME            STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   AGE    VOLUMEMODE
task-pv-claim   Bound    task-pv-volume   10Gi       RWO            manual         2m6s   Filesystem

```

## Deploy a POD that use the pvc
The POD yaml file specify a pvc and not a pv. from the POD perspective the claim is the volume.
***persistent-volume-pod.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: task-pv-pod
spec:
  volumes:
    - name: task-pv-storage
      persistentVolumeClaim:
        claimName: task-pv-claim
  containers:
    - name: task-pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: task-pv-storage
```

```
$ kubectl create -f persistent-volume-pod.yaml
pod/task-pv-pod created

$ kubectl get pods -A -o wide
NAMESPACE              NAME                                        READY   STATUS      RESTARTS        AGE     IP              NODE       NOMINATED NODE   READINESS GATES
default                task-pv-pod                                 1/1     Running     0               13s     10.10.1.34      k-node1    <none>           <none>

```

As we see the POD has been scheduled on k-node1 and in this simple example the pod has claimed a volume (task-pv-claim) that will be mounted on ***/usr/share/nginx/html***.
The volume claim task-pv-claim is bound to the persistent volume (task-pv-volume) that is and *hostPath* (local filesystyem on the node) at the path ***/mnt/data***
So the result is that the POD will mount from k-node (the node on which is running on) filesystem the path /mnt/data on the POD filesystem /usr/share/nginx/html.
```
# Connect to k-node1 node and create a simple html page
$ ssh k-node1
$ sudo sh -c "echo 'Hello from Kubernetes storage' > /mnt/data/index.html"
$ exit

# Connect to the POD and verify the mount point content
$ kubectl exec -it task-pv-pod -- /bin/bash
root@task-pv-pod:/# ls -la  /usr/share/nginx/html/
total 4
drwxr-xr-x 2 root root 24 Jan 17 14:18 .
drwxr-xr-x 3 root root 18 Dec 29 19:28 ..
-rw-r--r-- 1 root root 30 Jan 17 14:18 index.html

# Verify nginx is returning the index.html page
root@task-pv-pod:/# curl http://localhost/
Hello from Kubernetes storage

```
