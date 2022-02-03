# Network Policies
* A Network Policy is like a firewall.
* By default, all pods can reach one another.
* Network isolation can be configured to block traffic to pods by running pods in dedicated namespaces.
* Between namespaces by default there is no traffic, unless routing has been configured.
* Network Policy can be used to block Egress as well as Ingress traffic, and it works like a firewall.
* Network Policy is a separate object in the API.

## Example 1
***pods-with-nw-policy.yaml***
```
kind: Pod   <- we create a POD
apiVersion: v1
metadata:
  name: database-pod
  namespace: default
  labels:
    app: database <- labeled database
spec:
  containers:
    - name: database
      image: alpine
---
 
kind: Pod  <- We create a second POD
apiVersion: v1
metadata:
  name: web-pod
  namespace: default
  labels:
    app: web  <- labeled web
spec:
  containers:
    - name: web
      image: alpine
 
---
 
kind: NetworkPolicy  <- We create a network policy
apiVersion: networking.k8s.io/v1
metadata:
  name: db-networkpolicy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: database  <- the policy apply to the database POD
  policyTypes:
  - Ingress
  - Egress
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: web <- Allow traffic from POD web
```
***Deployment***
```
# Create the two PODs and the network policy
$ kubectl create -f pods-with-nw-policy.yaml
pod/database-pod created
pod/web-pod created
networkpolicy.networking.k8s.io/db-networkpolicy created
 
# Check
$ kubectl get networkpolicy
NAME               POD-SELECTOR   AGE
db-networkpolicy   app=database   3m5s

```

## Example 2

* Here we create an nginx POD and nginx will respond on port 80.
* We make it available from outside the cluster using a Service which expose a NodePort
* We very the nginx is reachable using the exposed NodePort and the IP of the cluster node is running the nginx POD

***nginx-run.yaml***
```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: nginx-run-deployment
  name: nginx-run-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: nginx-run-app
  template:
    metadata:
      labels:
        k8s-app: nginx-run-app
      name: nginx-run-app
    spec:
      containers:
      - image: nginx:latest
        imagePullPolicy: Always
        name: nginx-run-app
      restartPolicy: Always
```
***Deployment***
```
$ kubectl create -f nginx-run.yaml
deployment.apps/nginx-run-app created
 
$ kubectl create -f nginx-run-svc.yaml
service/nginx-run-svc created
 
$ kubectl get services nginx-run-svc -o wide
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE   SELECTOR
nginx-run-svc   NodePort   10.104.184.69   <none>        80:32000/TCP   86m   k8s-app=nginx-run-app
 
$ kubectl get endpoints -o wide
NAME            ENDPOINTS            AGE
kubernetes      192.168.56.10:6443   27h
nginx-run-svc   10.36.0.0:80         88m
 
 
$ kubectl get deployments
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
nginx-run-app   1/1     1            1           2m58s
 
$ kubectl get replicaset
NAME                       DESIRED   CURRENT   READY   AGE
nginx-run-app-5887bf84fb   1         1         1       3m5s
 
$ kubectl get pods -o wide --show-labels
NAME                             READY   STATUS    RESTARTS      AGE    IP          NODE                      NOMINATED NODE   READINESS GATES   LABELS
dnsutils                         1/1     Running   2 (56m ago)   177m   10.39.0.1   k8s-node1.singleton.net   <none>           <none>            <none>
nginx-run-app-5887bf84fb-wrmt2   1/1     Running   0             89m    10.36.0.0   k8s-node2.singleton.net   <none>           <none>            k8s-app=nginx-run-app,pod-template-hash=5887
bf84fb
```
* As we can see the nginx service is exposing a random NodePort 32645 and point the the pod which match (selector) the label  k8s-app=nginx-run-app
* The service endpoint for the nginx-app-svc is defined to route traffic to  nginx-run-app  pod  IP 10.36.0.0
* The nginx pod ( we have one only replica here ) is matching the service selector label  and has been scheduled to run on k8s-node2.singleton.net. 
  We can then access the nginx web server in this way:
***Testing***
```
# $ curl -X GET http://k8s-node2.singleton.net:3264 use this if you have properly configured the node in /etc/hosts of the laptop
curl -X GET http://192.168.56.12:32645/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
 
<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>
 
<p><em>
```

We now change the service port t 32000  and verify that we can still access the nginx web service

```
# Edit the service and change NodePort to be 32000
$ kubectl edit service nginx-run-svc
service/nginx-run-svc edited
 
# Verify the changes
$ kubectl get services
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP        26h
nginx-run-svc   NodePort    10.104.184.69   <none>        80:32000/TCP   59m
 
$ curl -X GET http://192.168.56.12:32000/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
 
<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>
 
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

