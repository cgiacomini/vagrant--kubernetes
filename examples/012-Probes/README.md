# Probes
Probes are part of the containers specs and can be used to test the access to the PODs
They are meant to be use to verify that the application is reacting.
* ***readinessProbe***: used to make sure the POD is made available only when the readinessProbe succeed
* ***livenessProbe***: is used to check the availability of a POD during its life time.
They both work the same way but

For each probe there are three possible types:

* ***exec***: is a command that when execute should return **0** as the exit value
* ***httpGet***: is an http request that should returns a response code between 200 and 399
* ***tcpSocket***: verify that a specific socket connecivity ( a port ) is available.
## readinessProbe - exec example
In the following POD the exec command is executed every 5 seconds
and the POD never get ready because the /tmp/noxistsfile never get created.
***001-readiness-probe-exec.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name : probe-test-ready
  namespace: default
spec:
  containers:
  - name: busybox
    image: busybox
    command:
      - sleep
      - "3600"
    readinessProbe:
      periodSeconds: 5
      exec:
        command:
          - cat
          - /tmp/noexistsfile
```
***Testing***
```
# Deploy the POD
$ kubectl apply -f 001-readiness-probe-exec.yaml
pod/probe-test-ready created

# Get the POD status
$ kubectl get pod
NAME               READY   STATUS    RESTARTS   AGE
probe-test-ready   0/1     Running   0          8s

# Check for possible issues 
$ kubectl describe pod probe-test-ready
Name:         probe-test-ready
Namespace:    default
...
...
Events:
  Type     Reason     Age              From               Message
  ----     ------     ----             ----               -------
  Normal   Scheduled  11s              default-scheduler  Successfully assigned default/probe-test-ready to k-node1
  Normal   Pulling    10s              kubelet            Pulling image "busybox"
  Normal   Pulled     9s               kubelet            Successfully pulled image "busybox" in 1.800856459s
  Normal   Created    8s               kubelet            Created container busybox
  Normal   Started    8s               kubelet            Started container busybox
  Warning  Unhealthy  1s (x4 over 7s)  kubelet            Readiness probe failed: cat: can't open '/tmp/noexistsfile': No such file or directory

```
The POD will become ready only if and when the file /tmp/noexistsfile is present
```
# Connect to the pod and create the file manually
$ kubectl exec probe-test-ready -it -- /bin/sh
/ # echo "Hello"  > /tmp/noexistsfile
/ # cat /tmp/noexistsfile
Hello
/ # exit

# Verify that the pod is now ready
$ kubectl get pods
NAME               READY   STATUS    RESTARTS   AGE
probe-test-ready   1/1     Running   0          100s

# Check again the POD events
$ kubectl describe pod probe-test-ready
Name:         probe-test-ready
Namespace:    default
...
...
Events:
  Type     Reason     Age                     From               Message
  ----     ------     ----                    ----               -------
  Normal   Scheduled  4m42s                   default-scheduler  Successfully assigned default/probe-test-ready to k-node1
  Normal   Pulling    4m42s                   kubelet            Pulling image "busybox"
  Normal   Pulled     4m40s                   kubelet            Successfully pulled image "busybox" in 1.629896306s
  Normal   Created    4m40s                   kubelet            Created container busybox
  Normal   Started    4m40s                   kubelet            Started container busybox
  Warning  Unhealthy  3m17s (x21 over 4m39s)  kubelet            Readiness probe failed: cat: can't open '/tmp/noexistsfile': No such file or directory

```
A warning is reported stating that the POD has been Unhealthy for 3m17s along with the error messages.

## readinessProbe - httpGet example
Here the readiness probe is testing using **httpGet** probe type
***002-readiness-probe-httpget.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name : probe-test-ready-httpget
  namespace: default
spec:
  containers:
  - name: nginx-probe
    image: nginx
    ports:
        - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
```
***Testing***
```
# Deploy the POD
$ kubectl deploy -f 002-readiness-probe-httpget.yaml
pod/probe-test-ready-httpget created

$ kubectl get pods
NAME                       READY   STATUS    RESTARTS   AGE
probe-test-ready-httpget   0/1     Running   0          3s

$ kubectl get pods
NAME                       READY   STATUS    RESTARTS   AGE
probe-test-ready-httpget   0/1     Running   0          5s

$ kubectl get pods
NAME                       READY   STATUS    RESTARTS   AGE
probe-test-ready-httpget   1/1     Running   0          11s

$ kubectl describe pod probe-test-ready-httpget
Name:         probe-test-ready-httpget
Namespace:    default
Priority:     0
Node:         k-node1/192.168.56.11
Start Time:   Thu, 20 Jan 2022 10:14:56 +0100
Labels:       <none>
Annotations:  <none>
Status:       Running
IP:           10.10.1.52
IPs:
  IP:  10.10.1.52
Containers:
  nginx-probe:
    Container ID:   docker://22514588d56af4c89915ba6707ecbbafa0e31d7684f72d404ec95b37dffbcc54
    Image:          nginx
    Image ID:       docker-pullable://nginx@sha256:0d17b565c37bcbd895e9d92315a05c1c3c9a29f762b011a10c54a66cd53c9b31
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Thu, 20 Jan 2022 10:14:58 +0100
    Ready:          True
    Restart Count:  0
    Readiness:      http-get http://:80/ delay=5s timeout=1s period=10s #success=1 #failure=3
    Environment:    <none>
...
...

```
In The POD description the Readiness probe is reporting that it failed 3 times


## readinessProbe - tcpSocket example
Here the readiness probe is testing using **tcpsocket** probe type if the port **80** is available.
It will wait 5 seconds (nitialDelaySeconds: 5) before testing the port availability and 
it retries every 10 seconds (periodSeconds: 10). During the first 5 seconds then the POD status is not READY.

***003-readiness-probe-tcpsocket.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name : probe-test-ready-tcpsocket
  namespace: default
spec:
  containers:
  - name: nginx-probe
    image: nginx
    readinessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
```
***Testing***

```
# Deploy the pod
$ kubectl apply -f 003-readiness-probe-tcpsocket.yaml
pod/probe-test-ready-tcpsocket created

# Check pod status
$ kubectl get pods
NAME                         READY   STATUS              RESTARTS   AGE
probe-test-ready-tcpsocket   0/1     ContainerCreating   0          4s

# Check pod status after 5 secs
$ kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
probe-test-ready-tcpsocket   0/1     Running   0          6s

# Check pod status after 10 secs
$ kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
probe-test-ready-tcpsocket   1/1     Running   0          11s

# Check the POD description
$ kubectl describe pod probe-test-ready-tcpsocket
Name:         probe-test-ready-tcpsocket
Namespace:    default
Priority:     0
Node:         k-node1/192.168.56.11
Start Time:   Thu, 20 Jan 2022 09:50:27 +0100
Labels:       <none>
Annotations:  <none>
Status:       Running
IP:           10.10.1.49
IPs:
  IP:  10.10.1.49
Containers:
  nginx-probe:
    Container ID:   docker://8783f8dc3c76d6049a4650ed718156b9e480ab3b17d7d19f3cbf49e4363ebf4a
    Image:          nginx
    Image ID:       docker-pullable://nginx@sha256:0d17b565c37bcbd895e9d92315a05c1c3c9a29f762b011a10c54a66cd53c9b31
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Thu, 20 Jan 2022 09:50:30 +0100
    Ready:          True
    Restart Count:  0
    Readiness:      tcp-socket :80 delay=5s timeout=1s period=10s #success=1 #failure=3
```

In The POD description the Readiness probe is reporting that it failed 3 times. nginx container was not yet read.
Then once the container is ready  since the redinessprobe is execued with an intervall of 10 second,   
if we get the pods logs we see the the GET executed with 10 sec period.
```
kubectl logs probe-test-ready-httpget
...
10.10.2.1 - - [18/Nov/2022:10:07:19 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.25" "-"
10.10.2.1 - - [18/Nov/2022:10:07:29 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.25" "-"
10.10.2.1 - - [18/Nov/2022:10:07:39 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.25" "-"
10.10.2.1 - - [18/Nov/2022:10:07:49 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.25" "-"
10.10.2.1 - - [18/Nov/2022:10:07:59 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.25" "-"
```

## readinessProbe - Start PODs in order example
The following esample will start container **app** only when container **webapp** is ready.
**redinessProbe** in conatiner **app** is in fact waiting till the port **80** is available.

***004-probes-example.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name : probes-example
  namespace: default
spec:
  containers:
  - name: webapp
    image: nginx
    ports: 
    - containerPort: 80
  - name: app
    image: busybox
    readinessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 10
    command:
      - sleep
      - "3600"
```
