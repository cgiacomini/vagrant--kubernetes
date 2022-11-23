# Ephemeral Containers

[ ***Ref:*** Super article abut ephemeral containers : https://iximiuz.com/en/posts/kubernetes-ephemeral-containers]

* Sometimes container's don’t have any Unix utility tools preinstalled not even a shell; Ephemeral container can be deployed for troubleshooting of these minimal  containers that usually not allow the usage of the exec command.  
* Kubernetes provide the ***kubectl debug*** command to add an ephemeral container to a running Pod for debugging purposes.  
* The ephemeral container could be used to inspect the other containers in the Pod regardless of their state and content.
* Kubernetes POD's spec has the attribute ***ephemeralContainers*** to holds a list of Container-like objects.
* This attribute is one of the few Pod spec attributes that can be modified for an already created Pod instance.


Here we install a [side-car](../001-side-car/README.md) application to simulate a simple minimal pod.  
It run busybox with all tools and bash but is just for demonstration purpose.

We deploy the application and then we add to it an ephemeral container
```
$ kubectl get pods -A
NAMESPACE              NAME                                         READY   STATUS    RESTARTS         AGE
ckad                   side-car-pod                                 2/2     Running   0                50s

# add a busybox ephemeral container to the POD
kubectl debug -it --attach=false -c debugger --image=busybox  side-car-pod -n ckad

# Verify the POD'spec now has a new property called ephemeralContainers.
$ kubectl get pod side-car-pod -n ckad -o jsonpath='{.spec.ephemeralContainers}'
[{"image":"busybox","imagePullPolicy":"Always","name":"debugger","resources":{},"stdin":true,"terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","tty":true}]

# Verify the POD's ephemeral containers status
$ kubectl get pod side-car-pod -n ckad -o jsonpath='{.status.ephemeralContainerStatuses}'
[{"containerID":"containerd://6ff49a5ebbb729ab81fb538d36fca431141a0b8cc987a75d5db89bc3d492688a
","image":"docker.io/library/busybox:latest","imageID":"docker.io/library/busybox@sha256:fcd85228d7a25feb59f101ac3a955d27c80df4ad824d65f5757a954831450185","lastState":{},"name":"debugger","ready":false,"restartCount":0,"state":{"running":{"startedAt":"2022-11-22T15:46:27Z"}}}]

```
Now we can attach to the ephemeral container using the following command
```
# Attach to the running ephemeral container
$ kubectl attach -it -c debugger side-car-pod -n ckad
/ #
/ # wget -O - localhost/date.txt
Connecting to localhost (127.0.0.1:80)
writing to stdout
Tue Nov 22 15:50:07 UTC 2022
Tue Nov 22 15:50:17 UTC 2022
Tue Nov 22 15:50:27 UTC 2022
Tue Nov 22 15:50:37 UTC 2022
Tue Nov 22 15:50:47 UTC 2022

```
From the shell we opened on the ephemeral container we can certainly run curl since the containers share the same networks.  
and localhost correspond on the POD IP. But how to see the running process and the filesystem of the application containers  
from the ephemeral one ?  
Looks like thatephaemeral container run with an isolated process namespace so that ps does not reveal processes in other containers.  
Kubernetes says that when using ephemeral containers, it's helpful to enable process namespace sharing so you can view processes in other containers.
to do so we need to add ***--target*** option to our command line to target the container we want to attach and inspect with the ephemeral container.
## Attach an ephemeral container to a specif POD container

### Attach an ephemeral container to side-car container of the side-car-pod

```
# Attach an ephemeral container to the side-car container of the side-car-pod
$ kubectl debug -it --attach=false  side-car-pod --image=busybox  -it --target side-car -n ckad
Targeting container "side-car". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-nt9st.

# Attach to the ephemeral container. From There we can now see the **side-car** container processes
$ kubectl attach -it -c debugger-nt9st side-car-pod -n ckad
If you don't see a command prompt, try pressing enter.
/ # ls
bin   dev   etc   home  proc  root  sys   tmp   usr   var
/ # curl
sh: curl: not found
/ # ps
PID   USER     TIME  COMMAND
    1 root      0:00 {apachectl} /bin/sh /usr/sbin/apachectl -DFOREGROUND
    8 root      0:00 /usr/sbin/httpd -DFOREGROUND
    9 48        0:00 /usr/sbin/httpd -DFOREGROUND
   10 48        0:00 /usr/sbin/httpd -DFOREGROUND
   11 48        0:00 /usr/sbin/httpd -DFOREGROUND
   12 48        0:00 /usr/sbin/httpd -DFOREGROUND
   13 48        0:00 /usr/sbin/httpd -DFOREGROUND
   14 root      0:00 sh
   21 root      0:00 ps
/ #
```

### Attach an ephemeral container to app container of the side-car-pod

```
Attach an ephemeral container to the app container of the sid-car-pod
$ kubectl debug -it --attach=false  side-car-pod --image=busybox  -it --target app
Targeting container "app". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-ckzbp.

# Attach to the ephemeral container. From There we can now see the **app** container processes
$ kubectl attach -it -c debugger-ckzbp app -car-pod -n ckad

$ kubectl attach -it -c  debugger-ckzbp side-car-pod -n ckad
If you don't see a command prompt, try pressing enter.
/ # ps
PID   USER     TIME  COMMAND
    1 root      0:00 /bin/sh -c while true; do date >> /var/log/date.txt; sleep 10; done
   27 root      0:00 sh
   68 root      0:00 sleep 10
   69 root      0:00 ps
/ #

```

### Attach an ephemeral container to see all containers process from the debugger one

Alternative way is to make all container to share all process using the attribute: ***shareProcessNamespace: true***   
as in the following YAML file :

***side-car-pod.yaml***
```
kind: Pod
apiVersion: v1
metadata:
  name: side-car-pod
spec:
  shareProcessNamespace: true
  volumes:
  - name: logs
    emptyDir: {}

  containers:
  - name: app
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do date >> /var/log/date.txt; sleep 10; done"]
    volumeMounts:
    - name: logs
      mountPath: /var/log

  - name: side-car
    image: centos/httpd
    ports:
    - containerPort: 80
    volumeMounts:
    - name: logs
      mountPath: /var/www/html
```

Deploy the POD

```
$ k apply -f side-car-pod.yaml
pod/side-car-pod created

$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
side-car-pod   2/2     Running   0          4s

# attach an ephemeral container to any of the container of the POD
$ kubectl debug -it --attach=false  side-car-pod --image=busybox  -it --target side-car -n ckad
Targeting container "side-car". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-jkd6f.

# Open a shell to the debugger and check the list of process
$  kubectl attach -it -c debugger-jkd6f side-car-pod  -n ckad
If you don't see a command prompt, try pressing enter.
/ # ps
PID   USER     TIME  COMMAND
    1 65535     0:00 /pause
    7 root      0:00 /bin/sh -c while true; do date >> /var/log/date.txt; sleep 10; done
   15 root      0:00 {apachectl} /bin/sh /usr/sbin/apachectl -DFOREGROUND
   23 root      0:00 /usr/sbin/httpd -DFOREGROUND
   24 48        0:00 /usr/sbin/httpd -DFOREGROUND
   25 48        0:00 /usr/sbin/httpd -DFOREGROUND
   26 48        0:00 /usr/sbin/httpd -DFOREGROUND
   27 48        0:00 /usr/sbin/httpd -DFOREGROUND
   28 48        0:00 /usr/sbin/httpd -DFOREGROUND
  103 root      0:00 sh
  140 root      0:00 sleep 10
  141 root      0:00 ps
```

We can also explore each individaul containers filesystem.  
Knowing the PID of the running process in a container, from the ephemeral container, we can access its filesystem at ***/proc/(PID)/root***
so for the container named **app** running busybox, we can see the PID of the while loop is **7**, so we can access the root filesystem as follow:
```
/ # ls /proc/7/root
bin   dev   etc   home  proc  root  sys   tmp   usr   var
/ #
```
