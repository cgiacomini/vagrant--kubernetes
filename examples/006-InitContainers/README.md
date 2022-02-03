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
$ kubectl create -f init-example2.yaml
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

