# NodePort - Service
* This service type define and expose a static port which is available on all worker nodes within the Kubernetes cluster ( here in this example port 30887 ).
* NodePort ports are in the range of 30000 -32767. 
* If not specified in the yaml file Kubernetes choose a random available  one within the range.
* NodePort service span on all nodes.
* This kind of services exposure is considered not secure because we directly open a port to directly talk to each worker node.

## Example 
The sidecar service is of type NodePort here.  
The traffic comming on the kubernetes nodes on port 30877 is redirected to this service on  port 8080.
The service exposes port 8080 and redirect traffice to the target the endponts (PODS) on port 80.  
***sidecar-svc.yaml***
```
apiVersion: v1
kind: Service
metadata:
  name: sidecar-svc
spec:
  type: NodePort
  selector:
    app: sidecar
  ports:
  - port: 8080
    name: http-port
    targetPort: 80
    nodePort: 30887
```
The application here exposes the port 80  
***sidecar.yaml***
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sidecar-app
  labels:
    app: sidecar
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sidecar
  template:
    metadata:
      labels:
        app: sidecar
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
 
      - name: sidecar
        image: centos/httpd
        ports:
        - containerPort: 80
        volumeMounts:
        - name: logs
          mountPath: /var/www/html
```
## Deployment the application
```
$ kubectl apply -f sidecar.yaml
deployment.apps/sidecar-app created
 
$ kubectl get pods -o wide
NAME                           READY   STATUS    RESTARTS   AGE   IP          NODE                      NOMINATED NODE   READINESS GATES
sidecar-app-6f58cd9946-6p2mj   2/2     Running   0          25s   10.39.0.0   k8s-node1.singleton.net   <none>           <none>
sidecar-app-6f58cd9946-bc2nt   2/2     Running   0          25s   10.36.0.1   k8s-node2.singleton.net   <none>           <none>
sidecar-app-6f58cd9946-sgl5n   2/2     Running   0          25s   10.36.0.0   k8s-node2.singleton.net   <none>           <none>
```
## Deployment the NodePort Service
```
$ kubectl apply -f sidecar-svc.yaml
service/sidecar-svc created
 
$ kubectl get services -o wide
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE    SELECTOR
sidecar-svc   NodePort    10.100.57.117   <none>        8080:30887/TCP   10s    app=sidecar

$ kubectl get services
NAME          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
sidecar-svc   NodePort   10.104.86.107   <none>        8080:30887/TCP   2m54s
```

## Testing
To verify we can target the sidecar-app application via the nodePort service we need to identify first the node IP address on which the application PODs are running
```
$ kubectl get pods -o wide
NAME                           READY   STATUS    RESTARTS   AGE   IP          NODE                      NOMINATED NODE   READINESS GATES
sidecar-app-6f58cd9946-6p2mj   2/2     Running   0          25s   10.39.0.0   k8s-node1.singleton.net   <none>           <none>
sidecar-app-6f58cd9946-bc2nt   2/2     Running   0          25s   10.36.0.1   k8s-node2.singleton.net   <none>           <none>
sidecar-app-6f58cd9946-sgl5n   2/2     Running   0          25s   10.36.0.0   k8s-node2.singleton.net   <none>           <none>
```
There 2 PODs on k8s-node2 and one POD on k8s-node1 on all these nodes the nodePort Services have exposed port 30887  
We need now to find out the nodes IPs
```
$ kubectl get nodes -o wide
NAME                       STATUS   ROLES                  AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION                 CONTAINER-RUNTIME
k8s-master.singleton.net   Ready    control-plane,master   89d   v1.22.1   192.168.56.10   <none>        CentOS Linux 8   4.18.0-305.17.1.el8_4.x86_64   docker://20.10.8
k8s-node1.singleton.net    Ready    <none>                 89d   v1.22.1   192.168.56.11   <none>        CentOS Linux 8   4.18.0-305.17.1.el8_4.x86_64   docker://20.10.8
k8s-node2.singleton.net    Ready    <none>                 89d   v1.22.1   192.168.56.12   <none>        CentOS Linux 8   4.18.0-305.17.1.el8_4.x86_64   docker://20.10.8
```
So now that we  have put all pieces together we can target the application.
```
$ curl http://192.168.56.11:30887/date.txt
Wed Dec  8 16:33:22 UTC 2021
Wed Dec  8 16:33:32 UTC 2021
Wed Dec  8 16:33:42 UTC 2021
Wed Dec  8 16:33:52 UTC 2021
Wed Dec  8 16:34:02 UTC 2021
Wed Dec  8 16:34:12 UTC 2021
Wed Dec  8 16:34:22 UTC 2021
Wed Dec  8 16:34:32 UTC 2021
Wed Dec  8 16:34:42 UTC 2021
```
