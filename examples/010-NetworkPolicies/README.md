# Network Policies
* A Network Policy is like a firewall.
* By default, pods can communicate with each other irrespective of their namespace.
* Network isolation can be configured to block traffic to pods by running pods in dedicated namespaces.
* Network Policy can be used to block Egress as well as Ingress traffic, and it works like a firewall.
* Network Policy is a separate object in the API.

## Example 1
***001-pod-with-nw-policy.yaml***
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
$ kubectl create -f 001-pod-with-nw-policy.yaml
pod/database-pod created
pod/web-pod created
networkpolicy.networking.k8s.io/db-networkpolicy created
 
# Check
$ kubectl get networkpolicy
NAME               POD-SELECTOR   AGE
db-networkpolicy   app=database   3m5s

```

# Isolata PODs in a Namespace
## Disallow all traffic
We can block all ingress and egress communication to all PODs. we start by preparing the followin yaml file.
***002-disallow-traffic.yaml***
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ckad
spec:
  podSelector: {} <-- apply to all PODs
  policyTypes:
  - Ingress
  - Egress
```

we now create two pods and try to make them to communicate together.
```
# Create Backend POD
$ kubectl run backend --image nginx -n ckad --port=80
pod/backend created

# Create Frontend POD
$ k run frontend --image busybox -n ckad -- /bin/sh -c 'sleep 3600'
pod/frontend created
# Verify PODs deployment
$ kubectl get pod -n ckad -o wide
NAME       READY   STATUS    RESTARTS   AGE     IP           NODE        NOMINATED NODE   READINESS GATES
backend    1/1     Running   0          4m46s   10.10.2.68   k8s-node2   <none>           <none>
frontend   1/1     Running   0          3m3s    10.10.2.70   k8s-node2   <none>           <none>

# From the fronted we try to query the backend
$ kubectl exec frontend -n ckad -it -- wget --spider --timeout=1 10.10.2.68
Connecting to 10.10.2.68 (10.10.2.68:80)
remote file exists
```
Communication between the two PODs works. We now apply the network policy to block all traffic.
```
$ kubectl apply -f 002-disallow-traffic.yaml
networkpolicy.networking.k8s.io/default-deny-all created





