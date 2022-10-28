# Headless Services (Internal Services)

In some situations it is desired to be able to retrieve the IP addresses of all the pods that are connected to a certain service.
For example,  when pods are stateful, like a deployed databases and the client want to communicate to one of the PODs selectively, or when pods need to communicate each other.
In such situation PODs replicas are not identical, they have their individual state and characteristics.
For example on Couchbase we can address N1QL queries only to those Couchbase cluster nodes that has n1ql service,
or in case of MYSQL where a new worker node need to connect to one another worker to synchronize.

In this situations we need to be able to communicate to a specific POD directly, but how we can do that?
We could query the API call to the Kubernetes API server to return a list of PODs and their IP addresses , but that would be inefficient.

Here is where the headless service come to handy.

To avoid requests being load-balanced behind one single IP address of the services, we can explicitly specifying *ClusterIP* property to be equal *"None”*.

As seen before Kubernetes also create a DNS record for each POD behind a specific service and we can use nslookup to discover PODs IP addresses.
Usually when we perform a nslookup  for a service Kubernetes return the single IP address of the service ( the service's ClusterIP address).
However we can tell Kubernetes we do not need a cluster IP address for the service  explicitly specifying ClusterIP property to be equal "None”.
This way Kubernetes won’t allocate any IP address to the service but still create DNS records for the service and each endpoint;
when doing a nslookup of the service,  ***Kubernetes will return the POD's IP address instead.***

### Deply Headless Service
```
# Deploy the application
$ kubectl create -f sidecar.yml
deployment.apps/sidecar-app created

# Check the application is deployed
$ Kubectl get pods
NAMESPACE     NAME                                               READY   STATUS    RESTARTS         AGE
default       curl                                               1/1     Running   3 (115m ago)     19d
default       sidecar-app-6f58cd9946-8zdkl                       2/2     Running   0                2m39s
default       sidecar-app-6f58cd9946-cvbc7                       2/2     Running   0                2m38s
default       sidecar-app-6f58cd9946-mq6jc                       2/2     Running   0                2m38s
...

# Create the headless service (ClusterIP: None)
$ kubectl create -f sidecar-svc-headles.yml
service/sidecar-svc-headless created

# Check the service has no ClusterIP
$ kubectl get services
NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
sidecar-svc-headless   ClusterIP   None             <none>        8080/TCP   8s
...

# Get PODs IPs by viewing the service endpoints
$ kubectl get endpoints sidecar-svc-headless
NAME                   ENDPOINTS                                AGE
sidecar-svc-headless   10.36.0.0:80,10.36.0.1:80,10.39.0.1:80   19m

# Using CoreDNS to retrieve the PODs IPs by nslookup the service name
$ kubectl exec -it curl /bin/sh
[ root@curl:/ ]$ nslookup sidecar-svc-headless

Server: 10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name: sidecar-svc-headless
Address 1: 10.36.0.1 10-36-0-1.sidecar-svc-headless.default.svc.cluster.local
Address 2: 10.39.0.1 10-39-0-1.sidecar-svc-headless.default.svc.cluster.local
Address 3: 10.36.0.0 10-36-0-0.sidecar-svc-headless.default.svc.cluster.local
sidecar-svc-headless.yaml
```
