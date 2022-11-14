# ResourceQuota - Namespace

* It establishes the usable maximum amount of resources per namespace.  
* The kubernates scheduler will take care to enforce the rules when PODs are created.
* Once a resourceQuota is created for a specific namespace then all objects muast specify limits and requests in their manifests.

Here we create a namespce and we limit the resource it can use
* limit the number of running PODs in the namespace to 2
* limit the CPU number to 4 across all PODs for CPU limits
* limit the amount of memory available to 2G across all PODs for memory limits
* limit the ammount of requested CPU to 2  across all pods 
* limit the ammount of requested memory to 1G across all pods

## Examle

### The manifest YAML files

***limited-ns.yaml***
```
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    kubernetes.io/metadata.name: limited-ns
  name: limited-ns
```
***resources-quota.yaml***
```
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-quota
  namespace: limited-ns
spec:
  hard:
    pods: 2
    requests.cpu: 2
    requests.memory: 1G
    limits.cpu: 4 
    limits.memory: 2G
```

### Deployment and Verification
```
$ kubectl apply  -f limited-ns.yaml
namespace/limited-ns created

$ kubectl apply  -f resources-quota.yaml
resourcequota/resource-quota created

$ k describe resourcequota resource-quota -n limited-ns
Name:            resource-quota
Namespace:       limited-ns
Resource         Used  Hard
--------         ----  ----
limits.cpu       0     4
limits.memory    0     2G
pods             0     2
requests.cpu     0     2
requests.memory  0     1G
```

### Create a first POD in the limited namespace
```
$ kubectl run nginx1 --image=nginx --namespace limited-ns
Error from server (Forbidden): pods "nginx1" is forbidden: failed quota: resource-quota: must specify limits.cpu for: nginx1; limits.memory for: nginx1; requests.cpu for: nginx1; requests.memory for: nginx1
```
The creation of the pods is failed becase we did not specify the ammount of resurce ( memory and CPU ) the POD is intended to use.
Here we can create a YAML file to declaratively define the POD with the requested amount of resources to use.

***nginx1.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: nginx1
  namespace: limited-ns
spec:
  containers:
  - image: nginx
    name: nginx
    resources:
       requests:
         cpu: 0.5  # we request half CPU time. The resourceQuota is limiting us to 1 for requests.cpu.
         memory: 200M # we request 200M Bytes of memory. The resourceQuota is limiting us to 1G Bytes. 
       limits:
         cpu:  1 # we limit our pod tu use up to 1 CPU time. The resourceQuota is limiting us to 4 CPUs.
         memory: 400M # we linit our pod to use up to 400M byts of memory. The resourceQuota is limiting us to 2G Bytes
```

This time the pod is correctly created because the request and limits imposed by the resource quota are not passed.

```
$ kubectl apply -f nginx1.yaml
pod/limited-ns created

# Verify the status of the resurces
$ kubectl describe resourcequota/resource-quota -n limited-ns
Name:            resource-quota
Namespace:       limited-ns
Resource         Used  Hard
--------         ----  ----
limits.cpu       1     4   # We have an upper limit of 1 CPU over the 4 available.
limits.memory    400M  2G  # We have an upper limit to 400M over the 2G.
pods             1     2   # We have 1 pods. allowed are 2
requests.cpu     500m  2   # We use 500m CPU. allowed are 2
requests.memory  200M  1G  # We use 200M bytes. allowed are 1G.

```

### Create a 2nd POD 
We create a 2nd POD with same characteristics.  
we just change the metadata.name to be **nginx2**
***nginx2.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: nginx2
  namespace: limited-ns
spec:
  containers:
  - image: nginx
    name: nginx
    resources:
       requests:
         cpu: 0.5
         memory: 200M
       limits:
         cpu:  1
         memory: 400M
```

The resource-quota is updated showing the used amout of CPU and memory used by the two existing PODS
```
$ kubectl apply -f nginx2.yaml
pod/nginx2 created

# The second POD is created 
$ kubectl get pods -A
NAMESPACE    NAME      READY   STATUS      RESTARTS        AGE
limited-ns   nginx1    1/1     Running     0               4m35s
limited-ns   nginx2    1/1     Running     0               4s

# The resourceQuota also now tell us the we have 2 PODs running over the 2 allowed.
# We then reached the maximum of number of PODS we can run in this namespace.
$ kubectl describe resourcequota resource-quota -n limited-ns
Name:            resource-quota
Namespace:       limited-ns
Resource         Used  Hard
--------         ----  ----
limits.cpu       2     4
limits.memory    800M  2G
pods             2     2
requests.cpu     1     2
requests.memory  400M  1G
```

### Try to Create a 3nd POD 
We try to create a 3nd POD with same characteristics. 
We just change the metadata.name to be **nginx3**
```
$ kubectl apply -f nginx3.yaml
Error from server (Forbidden): error when creating "nginx3.yaml": pods "nginx3" is forbidden: exceeded quota: resource-quota, requested: pods=1, used: pods=2, limited: pods=2
```
It fails because we are requesting to start a 3rd POD while the namespace allows only 2 running pods in it.  

```
# We patch the reource quota to allow 4 running pods instead of only two and we try to re-deploy the 3rd POD
$ kubectl patch -p '{"spec":{"hard":{"pods":"4"}}}' resourcequota resource-quota -n limited-ns
resourcequota/resource-quota patched

# Verify the resource Quota
$ k describe resourcequota resource-quota -n limited-ns
Name:            resource-quota
Namespace:       limited-ns
Resource         Used  Hard
--------         ----  ----
limits.cpu       2     4
limits.memory    800M  2G
pods             2     4  # we can now run up to 4 pods in the namespace
requests.cpu     1     2
requests.memory  400M  1G

# Deploy the 3rd POD
$ kubectl apply -f nginx3.yaml
pod/nginx3 created

# Verify the pods are all running
$ kubectl get pods -n limited-ns
NAME     READY   STATUS    RESTARTS   AGE
nginx1   1/1     Running   0          12m
nginx2   1/1     Running   0          8m8s
nginx3   1/1     Running   0          12s

# Verify the resource quota.
kubectl describe resourcequota resource-quota -n limited-ns
Name:            resource-quota
Namespace:       limited-ns
Resource         Used   Hard
--------         ----   ----
limits.cpu       3      4
limits.memory    1200M  2G
pods             3      4
requests.cpu     1500m  2
requests.memory  600M   1G

```
The 3rd POD is running just fine since it does not overpass any imposed max requests and limits.
We see we still have **requests.cpu 1500m** and if we start a 4th POD that it requires a 1 CPU the deployment will fail since we can only request the 0.5 available.

```
$ kubectl apply -f nginx4.yaml
Error from server (Forbidden): error when creating "nginx4.yaml": pods "nginx4" is forbidden: exceeded quota: resource-quota, requested: limits.cpu=2,requests.cpu=1, used: limits.cpu=3,requests.cpu=1500m, limited: limits.cpu=4,req
uests.cpu=2
```
This tell us we requested 1 CPU the limit is 2 and we already have used 1.5 CPU, so no CPU available for the 4th POD.


