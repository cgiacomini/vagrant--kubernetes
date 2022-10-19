# side-car example
## Unique Container vs Multiple containers PODs
In most cases we only have one container in a POD because they are easier to build and maintain,
but when necessary we can also have more containers, in this case the following scenarios could apply:

![side-car](../../doc/side-car.jpg)

* ***side-car*** container is a container that enhances the primary application.
For instance for logging, or for a web application plus helpers containers.
* ***ambassador*** container  is a container that represents the primary container to the outside world such as a proxy.
* ***adapter*** container  which is used to adapt the traffic or data pattern to match the traffic or data pattern in other applications in the cluster.

***side-car.yaml***
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
## Deployment
```
# Create a namespace to use for all examples
$ kubectl create namespace training
namespace/training created
 
# Verify the namespace has been created
$ kubectl get namespaces
NAME              STATUS   AGE
default           Active   65d
kube-node-lease   Active   65d
kube-public       Active   65d
kube-system       Active   65d
training          Active   12s
 
# Set the the training namespace as our default one
$ kubectl config set-context --current --namespace=training
Context "kubernetes-admin@kubernetes" modified.
 
# Verify the context
$ kubectl config view --minify | grep namespace
    namespace: training
 
# Create the sidecas pod example
$ kubectl create -f side-car.yaml
pod/side-car-pod created
 
$  kubectl get pods
NAME          READY   STATUS    RESTARTS   AGE
side-car-pod   2/2     Running   0         16s
```
## Explanation
We connect to the sidecar container ( the web app ) of the sidecar-pod
The two containers uses the  **logs** volume
 * the busyboxcontainer mount it in **/var/log** and create and write the file **date.txt** in it
 * the webapp container mount it in **/var/www/html** as its root documents directory.
By using the web app we can then access the file date.txt

## Access the webapp
Here connect to the container insdide the POD to access the webapp
```
$ kubectl exec side-car-pod -it -c side-car -- /bin/bash
$ curl http://localhost/date.txt
Tue Aug 17 17:58:56 UTC 2021
Tue Aug 17 17:59:06 UTC 2021
Tue Aug 17 17:59:16 UTC 2021
Tue Aug 17 17:59:26 UTC 2021
Tue Aug 17 17:59:36 UTC 2021
Tue Aug 17 17:59:46 UTC 2021
Tue Aug 17 17:59:56 UTC 2021
Tue Aug 17 18:00:06 UTC 2021
```
## Port Forwarding
We can use port forwarding to access the internal app pod web application from outside the POD and directly on your local host via curl or web browser.
```
$ kubectl port-forward pod/side-car-pod 8080:80 &
$ Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80

$ curl http://localhost:8080/date.txt
Handling connection for 8080
Wed Aug 18 05:08:16 UTC 2021
Wed Aug 18 05:08:26 UTC 2021
Wed Aug 18 05:08:36 UTC 2021
Wed Aug 18 05:08:46 UTC 2021
Wed Aug 18 05:08:56 UTC 2021
Wed Aug 18 05:09:06 UTC 2021
Wed Aug 18 05:09:16 UTC 2021
Wed Aug 18 05:09:26 UTC 2021
Wed Aug 18 05:09:36 UTC 2021
Wed Aug 18 05:09:46 UTC 2021
```
