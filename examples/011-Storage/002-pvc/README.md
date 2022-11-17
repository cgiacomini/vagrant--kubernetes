# Persistent Volumes

##  PersistentVolume (PV)
* The **PersistentVolume** (PV) is a storage device in a Kubernetes cluster, completely decoupled from the PODs.
* The storage is provided as part of the kubernetes cluster by an administrator or dynamically provisioned using Storage Classes.
* There are different volumes types we can use:
  * EmptyDir : Create a temporary empty directory volume that can be mounted from al container inside the POD.
  * hostPath : File or directory from the host node’s filesystem
  * azureDisk :
  * awsElasticBlockStore :
  * gcePersistetDisk :
  * cephfs :
  * rdb :
  * fc :
  * iscsi :
  * nfs :
  * gitrepo :

A peristent volume can be created statically or dynamically.
* **static approach**: we need to refer a storage device by creating a *persistenVolume*.
* **dynamic approach**: does not require the creation of a persistent volume, it will be instead created automatically from the PersisteVolumeClaim by setting a **storageclassName**. A storage class provide a definition of storage types.

## PersistentVolumeClaims (PVC)
* The **PersistentVolumeClaim** requests the resources of a PersistentVolume (size and access type)
* It talk to the available backend storage provider to claim available volumes of the storge type. 
* Usually are the kubernetes administrators that setup a storage class.

## Example
In this example we use a directory (*C:/MyShare*) on the host machine (from where we run the Virtualbox hypervisor and our kubernets cluster's VMs)
as persitent volume. The directory is mounted as a Shared Folder on all k8s cluster nodes as a Vboxfs.
We then define a ***persistentVolume*** that define this storage resource and a ***persistentVolumeClaim*** to be used by a POD to clami persistent storage.

### Local Storage Preparation
Our kubernetes cluster is using virtualbox as hybervisor.
In this example we use a virtualbox shared folder as storage for our peristent volume, The shared storage is mounted on all kubernetes nodes.
So we need to setup a virutalbox shared folder on the host machine to be mounted automatically at boot time on all nodes of the cluster.
To do so we use the virtualbox **VBoxManage** command.

```
# My host is a windows machine running cygwin
$ mkdir /cygdrive/c/MyShare

# Get the list of VMs
$ VBoxManage.exe list vms
"k8s-master" {b98e9b30-9fcb-48ad-9e37-ed4378159d06}
"k8s-node1"  {fea0d68c-713b-4e4a-ba0c-3aebd14969b8}
"k8s-node2"  {4ce8542f-78a5-4255-bb3e-fee3879b11ae}

# Stop all VMs
$ VBoxManage.exe controlvm k8s-master poweroff
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%

$ VBoxManage.exe controlvm k8s-node1 poweroff
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%

$ VBoxManage.exe controlvm k8s-node2 poweroff
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%

# Add the MyShare folder as automanted shared folder on all cluster nodes
$ VBoxManage.exe  sharedfolder add k8s-master -name MyShare -hostpath "C:\MyShare" --auto-mount-point "/MyShare" --automount
$ VBoxManage.exe  sharedfolder add k8s-node1  -name MyShare -hostpath "C:\MyShare" --auto-mount-point "/MyShare" --automount
$ VBoxManage.exe  sharedfolder add k8s-node2  -name MyShare -hostpath "C:\MyShare" --auto-mount-point "/MyShare" --automount

# Restart the nodes
$ VBoxManage.exe startvm k8s-master
Waiting for VM "k8s-master" to power on...
VM "k8s-master" has been successfully started.

$ VBoxManage.exe startvm k8s-node1
Waiting for VM "k8s-node1" to power on...
VM "k8s-node1" has been successfully started.

$ VBoxManage.exe startvm k8s-node2
Waiting for VM "k8s-node2" to power on...
VM "k8s-node2" has been successfully started.
```
**Note**: the same above operation can be done using the Virtualbox UI.

All nodes have the mounted *MyShare* folder mount on **/MyShare** directory. 
The mount point is accessible by user **root** and group **voxfs**.
Normally **centos** user is configured by the installation process. 
**centos** is granted access rights to the content of the shared folder by adding it to the group **vboxfs**
```
$ sudo usermod -G vboxsf -a centos
```
Now the /MyShare folder can be used as local persistent storage volume and is also acessible on all nodes.

### Create a storageClass
Here a storageClass **manual** is definded. 
since we use a simple directory as local storage volume **provisioner** is set to ***kubernetes.io/no-provisioner***.

***storage-class-manual.yaml***
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: manual
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```
### Deploy the storage class
```
$ kubectl apply -f storage-class-manual.yaml
storageclass.storage.k8s.io/manual created

$ kubectl get sc manual -o wide
NAME     PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
manual   kubernetes.io/no-provisioner   Delete          WaitForFirstConsumer   false                  16s
```
### Create the persistent volume
Here a persistent volume is created using the storage class **manual** just defined. 
It will have a capacity of 10G Bytes and will be mounted read-write by a single node.
***hostpath*** specify that the peristent volume use a directory on the node to emulate a network-attached storage.

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
    path: "/MyShare"
```

### Deploy persistent-volume
```
$ kubectl create -f persistent-volume.yaml
persistentvolume/task-pv-volume created

$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
task-pv-volume   10Gi       RWO            Retain           Available           manual                  103s

```
### Create the persisten volume claim
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
### Deploy persistent volume claim
```
$ kubectl get pv -o wide
NAME                      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                                      STORAGECLASS   REASON   AGE   VOLUMEMODE
docker-registry-repo-pv   2Gi        RWO            Retain           Bound       docker-registry/docker-registry-repo-pvc                           20d   Filesystem
task-pv-volume            10Gi       RWO            Retain           Available                                              manual                  12m   Filesystem

$ kubectl get pvc -o wide
NAME            STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE   VOLUMEMODE
task-pv-claim   Pending                                      manual         67s   Filesystem

```
The pvc is in Pending state waiting for a consumer ( a POD ) to bound to it.

```
kubectl describe pvc task-pv-claim
Name:          task-pv-claim
Namespace:     ckad
StorageClass:  manual
Status:        Pending
Volume:
Labels:        <none>
Annotations:   <none>
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:
Access Modes:
VolumeMode:    Filesystem
Used By:       <none>
Events:
  Type    Reason                Age                  From                         Message
  ----    ------                ----                 ----                         -------
  Normal  WaitForFirstConsumer  9s (x13 over 2m58s)  persistentvolume-controller  waiting for first consumer to be created before binding
```
### Create a POD that use the pvc
The POD yaml file specify a pvc and not a pv. from the POD perspective the claim is the volume.
Here the pvc is mounted in  /usr/share/nginx/html from the pvc task-pv-storage
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
### Deploy a POD that use the pvc

```
$ kubectl create -f persistent-volume-pod.yaml
pod/task-pv-pod created

$ kubectl get pods -A -o wide
NAMESPACE              NAME                                        READY   STATUS      RESTARTS        AGE     IP              NODE       NOMINATED NODE   READINESS GATES
default                task-pv-pod                                 1/1     Running     0               13s     10.10.1.34      k-node1    <none>           <none>

# The pvc is now bound
$ kubectl get pvc
NAME            STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   AGE
task-pv-claim   Bound    task-pv-volume   10Gi       RWO            manual         5m44s


```

As we see the POD has been scheduled on k-node1 and in this simple example the pod has claimed a volume (task-pv-claim) that will be mounted on ***/usr/share/nginx/html***.
The volume claim task-pv-claim is bound to the persistent volume (task-pv-volume) that is and *hostPath* (local filesystyem on the node) at the path ***/mnt/data***
So the result is that the POD will mount from k-node1 (the node on which is running on) filesystem the path /mnt/data on the POD filesystem /usr/share/nginx/html.
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



