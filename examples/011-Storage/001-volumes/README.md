# Kubernetes Storage
* Files stored in a container will only live as long as the container is alive.
* **Pod volumes** can be used to allocate storage for container and stay alive as long as the POD is alive.
* **Persistent Volumes** (PV) allow POD do connect to external storage that can live and exists outside PODs
* To use Persistent Volumes PODs uses **Persistent Volumes Claims** (PVC) to request access to specific storage.
* **ConfiMaps** are specific volumes object that connect to configuration files and variables. 
* They are the best way to provide dynamic data within a POD.
* **Secrets** do the same as configmap but by encoding the data they contains.

## Pod Volumes
* The POD-local volume is create by defining the ***spec.volumes***  property in the POD YAML specification file.
* To use the POD-local volume the containers mounts the volume by specified in ***spec.containers.volumemounts***  in the POD YAML specification file.

Here the POD volume is created as an ***EmptyDir*** type and mounted in the two containers running centos7
on a specified mouthPath called */centos1* for container *centos1* and */centos2* for container *centos2*.

# Example 

***pod-volume-example.yaml***

```
apiVersion: v1
kind: Pod
metadata:
  name: pod-volume
spec:
  containers:
  - name: centos1
    image: centos:7
    command:
      - sleep
      - "3600"
    volumeMounts:
      - mountPath: /centos1
        name: test
  - name: centos2
    image: centos:7
    command:
      - sleep
      - "3600"
    volumeMounts:
      - mountPath: /centos2
        name: test
  volumes:
    - name: test
      emptyDir: {}
```
***Deployment***
```
# Deploy the example POD
$ kubectl create -f pod-volume-example.yaml
pod/pod-volume created
 
# Wait until both containers are up and running
$ kubectl get pods
NAME                           READY   STATUS    RESTARTS      AGE
pod-volume                     2/2     Running   0             5m47s
 
# Create a file on mounted volume in centos1 container
$ kubectl exec -it pod-volume -c centos1 -- touch /centos1/test
 
# Check the file exists on mounted volume in centos2 container
$ kubectl exec -it pod-volume -c centos2 --  ls -la /centos2
total 0
drwxrwxrwx 2 root root 18 Sep 15 03:12 .
drwxr-xr-x 1 root root 32 Sep 15 03:08 ..
-rw-r--r-- 1 root root  0 Sep 15 03:12 test
```
# Persistent Volumes

* Cluster resource that is used to store data. Is an abstract object that need to be bound  to a real physical storage provider
like local hard-drive from the cluster nodes or external NFS server, databases, cloud storages etc.
* There are different volumes types we can use:
    * EmptyDir : Create a temporary empty directory on the host
    * hostPath :
    * azureDisk :
    * awsElasticBlockStore :
    * gcePersistetDisk :
    * cephfs :                                      
    * rdb :
    * fc :
    * iscsi :
    * nfs :
    * gitrepo :

 Use kubectl explain ***pod.spec.volumes*** for description of all these types
