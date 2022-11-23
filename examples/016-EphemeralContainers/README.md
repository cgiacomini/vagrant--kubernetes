# Ephemeral Containers

Sometimes container's don’t have any Unix utility tools preinstalled not even a shell.
Ephemeral container can be deployed for troubleshooting of these minimal containers that usually not allow the usage of the exec command.
Kubernetes provide the ***kubectl debug*** command to add an ephemeral container to a running Pod for debugging purposes.
The ephemeral container could be used to inspect the other containers in the Pod regardless of their state and content.
Kubernetes POD's spec has the attribute ***ephemeralContainers*** to holds a list of Container-like objects.
This attribute is one of the few Pod spec attributes that can be modified for an already created Pod instance.

***side-car-pod.yaml***
```
kind: Pod
apiVersion: v1
metadata:
  name: side-car-pod
spec:
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

Deploy the application
```
$ kubectl apply -f side-car-pod.yaml
pod/side-car-pod created

$ k get pods -n ckad
NAME           READY   STATUS    RESTARTS   AGE
side-car-pod   2/2     Running   0          11s
```


## Attach en ephemeral container targeting the **app** conntainer of the ***side-car-pod*** POD

```
$ kubectl debug -it --attach=false  side-car-pod --image=busybox  -it --target app
Targeting container "app". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-zmzbt.

# Attach to the created dobugger ephemeral container
$ kubectl attach -it -c debugger-zmzbt side-car-pod -n ckad
If you don't see a command prompt, try pressing enter.
/ #

```

### From inside the ephemeral container we can inspect now the running process of the **app** container
```
/ # ps
PID   USER     TIME  COMMAND
    1 root      0:00 /bin/sh -c while true; do date >> /var/log/date.txt; sleep 10; done
   11 root      0:00 sh
   22 root      0:00 sleep 10
   23 root      0:00 ps

```

From inside the ephemeral container we can also query the side-car container to se if it reply to an http request as is supposed to be
This is possible because the containers share the same subenet among them.
```
$ kubectl attach -it -c debugger-zmzbt side-car-pod -n ckad
If you don't see a command prompt, try pressing enter.
/ # ps
PID   USER     TIME  COMMAND
    1 root      0:00 /bin/sh -c while true; do date >> /var/log/date.txt; sleep 10; done
   11 root      0:00 sh
   22 root      0:00 sleep 10
   23 root      0:00 ps

/ # wget -O - localhost/date.txt
Connecting to localhost (127.0.0.1:80)
writing to stdout
Wed Nov 23 08:56:11 UTC 2022
Wed Nov 23 08:56:21 UTC 2022
Wed Nov 23 08:56:31 UTC 2022
Wed Nov 23 08:56:41 UTC 2022
Wed Nov 23 08:56:51 UTC 2022
Wed Nov 23 08:57:01 UTC 2022
Wed Nov 23 08:57:11 UTC 2022
Wed Nov 23 08:57:21 UTC 2022
Wed Nov 23 08:57:31 UTC 2022
Wed Nov 23 08:57:41 UTC 2022
Wed Nov 23 08:57:51 UTC 2022
Wed Nov 23 08:58:01 UTC 2022
Wed Nov 23 08:58:11 UTC 2022
-                    100% |*****************************************************************************************************************************************************************************************************************************************|   377  0:00:00 ETA
written to stdout

```

### From inside the ephemeral container we can inspect now the filesystem of the **app** container
To access the attached container **app** filesystem there is a trick.
knowing the PID of a running process we can access it filesystem at ***/proc/PID/root***
```
/ # ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 /bin/sh -c while true; do date >> /var/log/date.txt; sleep 10; done
   11 root      0:00 sh
   48 root      0:00 sleep 10
   49 root      0:00 ps aux

# lets see what is the content of the /var/log/date.txt file
/ # cat /proc/1/root/var/log/date.txt
Wed Nov 23 08:56:11 UTC 2022
Wed Nov 23 08:56:21 UTC 2022
Wed Nov 23 08:56:31 UTC 2022
Wed Nov 23 08:56:41 UTC 2022
Wed Nov 23 08:56:51 UTC 2022
Wed Nov 23 08:57:01 UTC 2022
Wed Nov 23 08:57:11 UTC 2022
```
## Attach en ephemeral container targeting the **side-car** conntainer of the ***side-car-pod*** POD
```
$ kubectl debug -it --attach=false  side-car-pod --image=busybox  -it --target side-car
Targeting container "side-car". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-s5z9l.

# Attach to the created dobugger ephemeral container
$  kubectl attach -it -c debugger-s5z9l  side-car-pod -n ckad
If you don't see a command prompt, try pressing enter.
/ #

```

### From inside the ephemeral container we can instpect now the running process of the **sid-car-pod** container
```
/ # ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 {apachectl} /bin/sh /usr/sbin/apachectl -DFOREGROUND
    9 root      0:00 /usr/sbin/httpd -DFOREGROUND
   10 48        0:00 /usr/sbin/httpd -DFOREGROUND
   11 48        0:00 /usr/sbin/httpd -DFOREGROUND
   12 48        0:00 /usr/sbin/httpd -DFOREGROUND
   13 48        0:00 /usr/sbin/httpd -DFOREGROUND
   14 48        0:00 /usr/sbin/httpd -DFOREGROUND
   15 root      0:00 sh
   21 root      0:00 ps aux
/ #
```

### From inside the ephemeral container we can inspect now the filesystem of the **side-car** container
To access the attached container **side-car** filesystem we access it at ***/proc/PID/root***
```
# Let see what is the contents of the  /var/www/html/date.txt
/ # cat /proc/1/root/var/www/html/date.txt
Wed Nov 23 08:56:11 UTC 2022
Wed Nov 23 08:56:21 UTC 2022
Wed Nov 23 08:56:31 UTC 2022
Wed Nov 23 08:56:41 UTC 2022
Wed Nov 23 08:56:51 UTC 21G022
Wed Nov 23 08:57:01 UTC 2022
Wed Nov 23 08:57:11 UTC 2022
Wed Nov 23 08:57:21 UTC 2022
```

## Verify the side-car-pod POD spec now has a new property called ephemeralContainers.
The ***ephemeralContainers*** is showing the list of ephemeral containers we have attache to the POD.
We have attacched on ephemeral container to each pod containers and here is the list
```
$ kubectl get pod side-car-pod -n ckad -o jsonpath='{.spec.ephemeralContainers}'
[{"image":"busybox","imagePullPolicy":"Always","name":"debugger-zmzbt","resources":{},"stdin":true,"targetContainerName":"app","terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","tty":true},{"image":"busybox","imagePullPolicy":"Always","name":"debugg
er-s5z9l","resources":{},"stdin":true,"targetContainerName":"side-car","terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","tty":true}]
```

We can also check the status of the ephemerl containers :
```
$ kubectl get pod side-car-pod -n ckad -o jsonpath='{.status.ephemeralContainerStatuses}'

```

## Using POD's shareProcessNamespace: true  property
### Path the POD specifications
The  ***shareProcessNamespace: true*** enable a shared pid namespace for all the containers in a Pod.
So from an attached ephemeral container to any of the POD containers we can access the process runnig on all of them,
```
# Delete current runnung POD for cleanup
$ kubectl delete -f side-car-pod.yaml
pod/side-car-pod delete
```
We need to update ***side-car-pod.yaml*** to add **shareProcessNamespace: true** to the POD specification and redeploy the POD.
***side-car-pod.yaml***
```
kind: Pod
apiVersion: v1
metadata:
  name: side-car-pod
spec:
  shareProcessNamespace: true
...
...
...
```

### Deploy the POD and verification
```
$ kubectl get pods -n ckad
NAME           READY   STATUS    RESTARTS   AGE
side-car-pod   2/2     Running   0          2m4s

$ kubectl get pod side-car-pod -n ckad -o jsonpath='{.spec.shareProcessNamespace}'
true
```
### Attach an ephemeral container to any of the POD's containers
Now since all the containers share the pid namespaces we can see all process from the emphemeral container.

```
$ kubectl debug -it --attach=false  side-car-pod --image=busybox  -it --target side-car -n ckad
Targeting container "side-car". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
Defaulting debug container name to debugger-7z77r.

$  kubectl attach -it -c debugger-7z77r  side-car-pod -n ckad
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
   85 root      0:00 sh
   96 root      0:00 sleep 10
   97 root      0:00 ps
/ #
```
But since we have attache the ephemeral container to the *side-car* container we can only inspect its filesystem and
not the *app* one.

## Copy POD
For debugging a misbehaving POD we could also make a copy of it using the ***--copy-to <name>*** options of the **kubectl debug** command.
The new POD btw will not inherit the original POD's labels so it will not be accidentaly targeted by a potential service in front of it.

By adding the ***-share-processes*** option, the POD's containers will also share the process namespace.

```
# Deploy the original side-car-pd without shareProcessNamespace properties
$ kubectl apply -f side-car-pod.yaml
pod/side-car-pod configured

# Copy the pod
$ kubectl debug -it -c debugger --image=busybox --copy-to new-pod --share-processes side-car-pod --attach=false

# We see new-pod has one more container running in it. the dubugger one.
$ k get pods -n ckad
NAME           READY   STATUS    RESTARTS   AGE
new-pod        3/3     Running   0          14s
side-car-pod   2/2     Running   0          17s

# Attach to the debugger pod
$  kubectl attach -it -c debugger new-pod  -n ckad
If you don't see a command prompt, try pressing enter.
/ # ps
PID   USER     TIME  COMMAND
    1 65535     0:00 /pause
    7 root      0:00 /bin/sh -c while true; do date >> /var/log/date.txt; sleep 10; done
   15 root      0:00 {apachectl} /bin/sh /usr/sbin/apachectl -DFOREGROUND
   22 root      0:00 /usr/sbin/httpd -DFOREGROUND
   23 48        0:00 /usr/sbin/httpd -DFOREGROUND
   24 48        0:00 /usr/sbin/httpd -DFOREGROUND
   25 48        0:00 /usr/sbin/httpd -DFOREGROUND
   26 48        0:00 /usr/sbin/httpd -DFOREGROUND
   27 48        0:00 /usr/sbin/httpd -DFOREGROUND
   28 root      0:00 sh
   55 root      0:00 sleep 10
   56 root      0:00 ps

# From inside the debugger contaier we can also access each container filesystem
/ # ls /proc/7/root/var/log
date.txt

/ # ls /proc/15/root/var/www/html
date.txt
```
