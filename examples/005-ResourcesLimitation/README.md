# Resources limitation

* By default, a POD will use as much CPU and memory as necessary to do its work.
  This can be managed by using memory and CPU requests and limits in ***pod.spec.containers.resources***. 
  (resources limitation are set on a per-container basis using resources property)
  Memory, as well as CPU limits can be used.
* CPU limits are expressed in ***millicore*** or ***millicpu***, which is one thousands of a CPU core, that means that 500 millicore is half CPU core. 
* Memory limits can be set also. And they are converted to the ***--memory*** option that can be used by the Docker run command or anything similar.
* When being scheduled, the kube-scheduler ensures that the node that is running the PODs have all the requested resources available.
* So if a node doesn't have the resources, the POD won't run on it.


In the follow yaml file, for example for mysql container there is:
* a request at least 128Mi and a 1/4 of CPU.
* We request at least 64Mi minimum to be able to execute.
* We limit the memory usage to 128Mi maximum.
* We limit the CPU usage half CPU time

***001-ResourcesLimitation.yaml***
```
apiversion: v1
kind: Pods
metadata:
  name: frontend
spec:
  containers:
    name: db
    image: mysql
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: "password"
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
    - name: wp
      image: wordpress
      resources:
        requests:
          memory: "64Mi"
          cpu: "250m"
        limits:
          memory: "128Mi"
          cpu: "550m"
```
Because we have limited the ammount of memory that the **db (mysql)** container may use, we see that the POD is craching and in the pod description we can see that the reason is an outof memory (OOMKILL) error on the db container:
```
...
Containers:
  db:
    ...
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       OOMKilled
      ...
  wp:
     ...
     ...
Conditions:
  Type              Status
  Initialized       True
  Ready             False
  ContainersReady   False
  PodScheduled      True
...
...
Events:
  Type     Reason     Age                     From               Message
  ----     ------     ----                    ----               -------
  ...
  ...
  Warning  BackOff    2m59s (x16 over 6m56s)  kubelet            Back-off restarting failed container

```

We che increase the memory limit for the db container to have it running currectly.
```
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: db
    image: mysql
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: "password"
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"
  - name: wp
    image: wordpress
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```
