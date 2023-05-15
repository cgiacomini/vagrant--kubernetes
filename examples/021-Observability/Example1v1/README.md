# Counter
Counters track either the number or size of events.  
Here we extend the code to add a counter on how many time '/hello' has been called.

```
$ docker build  -t example-001:v1 .

$ docker images
REPOSITORY                                 TAG          IMAGE ID       CREATED          SIZE
example-001                                v1           21e3a4af6f17   33 seconds ago   86.8MB

$ docker tag  example-001:v1  centos8s-server.singleton.net:443/example-001:v1
$ docker images
REPOSITORY                                      TAG          IMAGE ID       CREATED              SIZE
example-001                                     v1           21e3a4af6f17   About a minute ago   86.8MB
centos8s-server.singleton.net:443/example-001   v1           21e3a4af6f17   About a minute ago   8

$ docker push centos8s-server.singleton.net:443/example-001:v1
The push refers to repository [centos8s-server.singleton.net:443/example-001]
3c733ef947da: Pushed
31c16f878e29: Pushed
0dc7a55d0f25: Pushed
f6c0cfa560bf: Pushed
d2f43e9a0aef: Pushed
b0f56ca192f9: Layer already exists
59a47c329acd: Layer already exists
ea113223a18f: Layer already exists
3efb846cc795: Layer already exists
7cd52847ad77: Layer already exists
v1: digest: sha256:8494bb359df38573848c813760e1db70b4e79b0ebcf3a0d70a61d56c2f3dbf55 size: 2414

$ kubectl apply -f example-001v1-deployment.yaml
deployment.apps/example-001v1 created

$ k get pods -n monitoring
NAME                                     READY   STATUS    RESTARTS        AGE
curl                                     1/1     Running   1 (3h ago)      3h1m
example-001-5c5684868b-ndtnx             1/1     Running   0               105m
example-001v1-9cc6ff6c9-v4mw6            1/1     Running   0               35s
node-exporter-9m25d                      1/1     Running   1 (7h49m ago)   30h
node-exporter-qh2qs                      1/1     Running   1 (7h49m ago)   30h
node-exporter-zqwg6                      1/1     Running   1 (7h49m ago)   30h
prometheus-deployment-847b77bd49-4bnnq   1/1     Running   0               88m

$ k apply -f example-001v1-configmap.yaml
configmap/prometheus-server-conf configured

$ k delete pod prometheus-deployment-847b77bd49-4bnnq -n monitoring
pod "prometheus-deployment-847b77bd49-4bnnq" deleted

k exec curl -n monitoring -it -- /bin/sh

$ http://10.10.1.197:8001/hello
/bin/sh: http://10.10.1.197:8001/hello: not found
[ root@curl:/ ]$ curl http://10.10.1.197:8001/hello
[ root@curl:/ ]$ curl http://10.10.1.197:8001/hello
[ root@curl:/ ]$ curl http://10.10.1.197:8001/hello
[ root@curl:/ ]$ curl http://10.10.1.197:8001/hello
[ root@curl:/ ]$ curl http://10.10.1.197:8001/hellis
```
see Prometheus UI
