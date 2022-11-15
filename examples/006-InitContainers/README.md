# Init Containers

* Init containers are additional containers in a pod. 
* They can be used to complete a task before the regular container is started.
* They can be useful if you need to prepare something in particular that is required by the regular container.

## Example 1

***001-InitExample.yaml*** 
```
# Kubernetes start first the init container
# Once the web httpd init container is started we start alpine
kind: Pod
apiVersion: v1
metadata:
  name: init-example1
spec:
  initContainers:
  - name: web
    image: httpd
  containers:
  - name: alpine
    image: alpine
```

The init container is started, it is a web server httpd. 
When running, it cannot notify itself when is done since httpd never ends,  
so that the alpine container does not  start.

```
# create the POD
$ kubectl create -f 001-InitExample.yaml
pod/init-example1 created
 
# Check the pod status
$ kubectl get pods
NAME            READY   STATUS     RESTARTS   AGE
init-example1   0/1     Init:0/1   0          2m24s
```

## Example 2
As an example of an init container that start and finish so that the others containers in the POD can start see the YAML below.

***002-InitExample.yaml***
```
# The Init container start a sleep  for 20 seconds.
# When finished the web container is started
kind: Pod
apiVersion: v1
metadata:
  name: init-example2
spec:
  initContainers:
  - name: sleepy
    image: httpd
    command: ['sleep', '20']
  containers:
  - name: web
    image: nginx
```

The initContainer sleep 20 sec, when finished the nginx service starts
```
# create the Pod
$ kubectl create -f 002-InitExample.yaml
pod/init-example1 created
 
# Check the pod status
$ kubectl get pods
NAME            READY   STATUS     RESTARTS   AGE
init-example2   0/1     Init:0/1   0          16s  <- the sleep is not yet done. init Container is not yet done
 
$ kubectl get pods
NAME            READY   STATUS            RESTARTS   AGE
init-example2   0/1     PodInitializing   0          29s   <- init Container is done the Pod is probably downloading the nginx image.
 
$ kubectl get pods
NAME            READY   STATUS    RESTARTS   AGE
init-example2   1/1     Running   0          33s  <- The Pod is now running the nginx container
```

To split up the initialization logic, work can be distributed the into multiple init containers.  
In case we have defined multiple init containers in the manifest file then they run in the order of definition.  
If an init container fails then the POD is restarted.

## Example 3
In this second example the init container create a document filled with the current date inside a voulme mounted on the following path /var/www/html, then sleep 20 seconds to simulate extra work.
Once finished the web application container starts. It also mount the same volume also as /var/www/html.
httpd process in the webapp container listen by default on port 80.

***003-InitExample.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: init-example3
spec:
  initContainers:
  - name: config
    image: busybox
    command: ['sh', '-c', 'mkdir -p /var/www/html && date  > /var/www/html/date.txt && sleep 20']
    volumeMounts:
    - name: configdir
      mountPath: "/var/www/html"
  containers:
  - image: centos/httpd
    name: webapp
    ports:
    volumeMounts:
    - name: configdir
      mountPath: "/var/www/html"
  volumes:
  - name: configdir
    emptyDir: {}
```
Deploy and access the webapp
```
# Deploy the application POD
$ kubectl apply -f 003-InitExample.yaml
pod/init-example3 created

# Verify the pod is running the initialization container 
$ kubectl get pods
NAME            READY   STATUS     RESTARTS   AGE
init-example1   0/1     Init:0/1   0          36m
init-example2   1/1     Running    0          35m
init-example3   0/1     Init:0/1   0          8s

# Afeter 20s the initialization is finished and the webapp container start 
$ kubectl get pods
NAME            READY   STATUS     RESTARTS   AGE
init-example1   0/1     Init:0/1   0          37m
init-example2   1/1     Running    0          35m
init-example3   1/1     Running    0          32s
```
To access the webapp from outside the POD we can instruct kubectl to tunnels the traffic from a specific port on our localhost machine  
to port (80) of the init-example3 POD.
```
$  kubectl port-forward pod/init-example3 8080:80 &
[1] 1498
$ Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80

# A job is running taking care of the tunneling
$ jobs
[1]+  Running                 kubectl port-forward pod/init-example3 8080:80 &

# connecting to the webapp to request date.txt doc
$ curl http://localhost:8080/date.txt
Handling connection for 8080
Tue Nov 15 11:36:30 UTC 2022

# Cleanup the job
$ kill %1
```

## Example 4
In this example we have a POD with two init containers. The init containers are execute in sequence following the order as they are declared in the manifest yaml file.  
The second init container, when executed,  will cause an error and the POD fails.   
We can always retrieve the logs for the failed init container and figure out what the issue come from.

***004-InitExample.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: init-example4
spec:
  initContainers:
  - name: config
    image: busybox
    command: ['sh', '-c', 'mkdir -p /var/www/html && date  > /var/www/html/date.txt && sleep 20']
    volumeMounts:
    - name: configdir
      mountPath: "/var/www/html"
  - name: config-error
    image: busybox
    command: ['sh', '-c', 'for i in 1 2 3 4 A; do sleep $i; done']
  containers:
  - image: centos/httpd
    name: webapp
    ports:
    volumeMounts:
    - name: configdir
      mountPath: "/var/www/html"
  volumes:
  - name: configdir
    emptyDir: {}
```

Deply and very
```
$ kubecl apply -f 004-InitExamlpe.yaml
pod/init-example4 created

cgiacomini@NCEL94641 ~/GitHub/vagrant-kubernetes/examples/006-InitContainers
$ kubecl get pods -
NAMESPACE              NAME                                         READY   STATUS      RESTARTS       AGE
ckad                   init-example4                                0/1     Init:0/2    0              3s

# after 20s the first init container has finished
$ kubecl get pods
NAME            READY   STATUS     RESTARTS   AGE
init-example4   0/1     Init:1/2   0          28s

# The second init container starts but end with error
$ kubecl get pods
NAME            READY   STATUS       RESTARTS   AGE
init-example4   0/1     Init:Error   0          36s

# We retrieve the logs to see what is the issue causing the error

$ kubecl logs init-example4  --container config-error
sleep: invalid number 'A'

# The POD is then now in error and try to restart by reesecuting the init containers
$ kubecl get pods
NAME            READY   STATUS                  RESTARTS      AGE
init-example4   0/1     Init:CrashLoopBackOff   7 (50s ago)   13m
