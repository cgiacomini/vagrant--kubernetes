# Security Context

Defines privileges and access control settings for a POD in a container.

It includes :

* Discretionary Access Control which is about permissions used to access an object.
* Security Enhanced Linux (SELinux) where security labels can be applied
* Running as privileged or unprivileged user
* Using Linux capabilities
* appArmor, which is an alternative to SELinux
* AllowProvilegeEscalation, which controls if a process can gain more privileges than its parent process.

## Example 1

***001-SecurityContextDemo.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: nginxsecure
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - image: nginx
    name: nginx
```

## Explanation

In this exampe we deploy whose container need to start as root, but since we have specified
**runAsNonRoot: true** as security context, the container will fail to start.

```
kubectl apply -f 001-SecurityContextDemo.yaml
pod/nginxsecure created

$ kubectl get pods -A
default                nginxsecure                                 0/1     CreateContainerConfigError   0               66s

$ kubectl describe pof nginxsecure
...
...
...
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  46s               default-scheduler  Successfully assigned default/nginxsecure to k-node1
  Normal   Pulled     3s                kubelet            Successfully pulled image "nginx" in 41.874012543s
  Normal   Pulling    2s (x2 over 45s)  kubelet            Pulling image "nginx"
  Warning  Failed     0s (x2 over 3s)   kubelet            Error: container has runAsNonRoot and image will run as root (pod: "nginxsecure_default(ec263204-c530-4991-a258-15fea1045041)", co
ntainer: nginx)
  Normal   Pulled     0s                kubelet            Successfully pulled image "nginx" in 1.667340538s

```

## Example 2

***002-SecurityContextDemo.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}
  containers:
  - name: sec-ctx-demo
    image: busybox
    command: [ "sh", "-c", "sleep 1h" ]
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo
    securityContext:
      allowPrivilegeEscalation: false
```

## Explanation

* In the configuration file, the runAsUser field specifies that for any Containers in the Pod, all processes run with user ID 1000. 
* The runAsGroup field specifies the primary group ID of 3000 for all processes within any containers of the Pod. 
* If this field is omitted, the primary group ID of the containers will be root(0). 
* Any files created will also be owned by user 1000 and group 3000 when runAsGroup is specified. 
* Since fsGroup field is specified, all processes of the container are also part of the supplementary group ID 2000. i
* The owner for volume /data/demo and any files created in that volume will be Group ID 2000.

```
$ kubectl apply -f 002-SecurityContextDemo.yaml
pod/security-context-demo created


$ kubectl get pod security-context-demo
NAME                    READY   STATUS    RESTARTS   AGE
security-context-demo   1/1     Running   0          2m55s

$ kubectl exec -it security-context-demo -- sh
/ $ ps
PID   USER     TIME  COMMAND
    1 1000      0:00 sleep 1h
   14 1000      0:00 sh
   21 1000      0:00 ps

/ $ cd /data
/ $ ls -l
total 0
drwxrwsrwx    2 root     2000             6 Nov 22 16:19 demo
/data $ cd demo
/data/demo $ echo hello > testfile
/data/demo $ ls -l
total 4
-rw-r--r--    1 1000     2000             6 Nov 22 16:22 testfile
/data/demo $ id
uid=1000 gid=3000 groups=2000
/data/demo $ exit
```
