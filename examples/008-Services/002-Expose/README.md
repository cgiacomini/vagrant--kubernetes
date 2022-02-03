# Deploy

```
$ kubectl create -f hello-world-dc.yaml
```

# Expose the deployment using kubectl to create a service of type NodePort
A Random NodePort is given to access the service. 
As an alternative we can use the option --targetPort to specify the port that should be used

```
$ kubectl expose deployment hello-world --type=NodePort --name=example-service
```

# Get The created services information. Here a NodePort 31124 as been randomly choosen.
```
$ kubectl get services
NAME              TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
example-service   NodePort   10.100.179.40   <none>        8080:31124/TCP   6m25s
```

# Get the IP of one of the cluster node that runs one of the PODs

```
$ kubectl get pods --selector="run=expose-example" --output=wide
NAME                           READY   STATUS    RESTARTS   AGE     IP          NODE                      NOMINATED NODE   READINESS GATES
hello-world-59b8cf7d86-s7psv   1/1     Running   0          7m41s   10.36.0.0   k8s-node2.singleton.net   <none>           <none>
hello-world-59b8cf7d86-x9vls   1/1     Running   0          7m41s   10.36.0.1   k8s-node2.singleton.net   <none>           <none>


$ kubectl get nodes -o wide
NAME                       STATUS   ROLES                  AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION                 CONTAINER-RUNTIME
k8s-master.singleton.net   Ready    control-plane,master   75d   v1.22.1   192.168.56.10   <none>        CentOS Linux 8   4.18.0-305.17.1.el8_4.x86_64   docker://20.10.8
k8s-node1.singleton.net    Ready    <none>                 75d   v1.22.1   192.168.56.11   <none>        CentOS Linux 8   4.18.0-305.17.1.el8_4.x86_64   docker://20.10.8
k8s-node2.singleton.net    Ready    <none>                 75d   v1.22.1   192.168.56.12   <none>        CentOS Linux 8   4.18.0-305.17.1.el8_4.x86_64   docker://20.10.8
```

# Target the choosen node IP withe the randomly chosen port (31124) to target the services

```
curl -X GET http://192.168.56.12:31124
```

ALL THIS CAN BE DONE USING NODEPORT SERVICE TYPE
