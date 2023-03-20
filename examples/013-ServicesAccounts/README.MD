# Services Account, Roles  and Roles binding  
***!!! TO BE REWORKED BECAUSE OF CHANGES IN KUBERNETES 1.24.0  !!!***

Any processes or applications in a container which resides within a POD
can access the cluster by getting authenticated to the API server,
using a service account.

* Services account are used for basic authentication
* Roles and Roles binding are used for authorization
* By default every POD uses a default serivice account
* Every namespaces has a default service account called ***default***

All namespaces as a default service account

```
$ kubectl get sa -A | grep default
default                default                              1         7d1h
ingress-nginx          default                              1         6d19h
kube-node-lease        default                              1         7d1h
kube-public            default                              1         7d1h
kube-system            default                              1         7d1h
kubernetes-dashboard   default                              1         7d1h

```

***default service account***
```
$ kubectl get sa default -n default -o yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2022-01-13T09:24:05Z"
  name: default
  namespace: default
  resourceVersion: "459"
  uid: c9616138-2365-42f0-802b-ed3579a2ad39
secrets:
- name: default-token-6rfps
```

When creating a ***serviceaccount*** a ***service account token*** is also generated (**Note:** not anymore from kubernetes [1.24.0](https://github.com/cgiacomini/vagrant--kubernetes) )
The token is used by an application to authenticate to the kubernetes API Server.
Every created pods mount the secret that contains the default service account token.

```
$ kubectl describe serviceaccount default -n default
Name:                default
Namespace:           default
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   default-token-6rfps
Tokens:              default-token-6rfps
Events:              <none>
```

The token ***default-token-6rfps*** is stored as a secret object
```
# Get The secret name
$ kubectl get secret -n default
NAME                  TYPE                                  DATA   AGE
default-token-6rfps   kubernetes.io/service-account-token   3      7d1h

# Show the secret content
$ kubectl describe secret  default-token-6rfps -n default
Name:         default-token-6rfps
Namespace:    default
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: default
              kubernetes.io/service-account.uid: c9616138-2365-42f0-802b-ed3579a2ad39
Type:  kubernetes.io/service-account-token
Data
====
ca.crt:     1099 bytes
namespace:  7 bytes
token:      eyJhbGciOiJSUzI1N.................
```

The secret has three data values all base64 encoded:
* ca.crt
* namespace
* thoken

This allow the service account to be used to connect the the API server.
## Create a POD
***mypod.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
  - name: mybod
    image: radial/busyboxplus
    command:
    - sleep
    - "3600"
```

***Deploy and Test***
```
## Deploy the POD
$ kubectl apply -f mypod.yaml
pod/mypod created

# Verify the POD is running
$ kubectl get pods
NAME    READY   STATUS    RESTARTS   AGE
mypod   1/1     Running   0          6s


## Get the POD YAML
$ kubectl get pod mypod -o yaml
apiVersion: v1
kind: Pod
...
...
spec:
  containers:
  - command:
    - sleep
    - "3600"
    image: radial/busyboxplus
    imagePullPolicy: Always
    name: mybod
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-9gjpv
      readOnly: true
...
...
  volumes:
  - name: kube-api-access-9gjpv
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          expirationSeconds: 3607
          path: token
      - configMap:
          items:
          - key: ca.crt
            path: ca.crt
          name: kube-root-ca.crt
      - downwardAPI:
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
            path: namespace
```

The created pod has mounted a default secret which contains the token curl can use to access the API server.
```
## Connect to the POD and try to access the API server via REST API without the token
$ kubectl exec mypod -it -- /bin/sh
/ # curl https://kubernetes/api/v1 --insecure
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "forbidden: User \"system:anonymous\" cannot get path \"/api/v1\"",
  "reason": "Forbidden",
  "details": {},
  "code": 403
}
````

The curl fails because it tries to access the API but is not alowed.
An access token should be provided.
```
DEFAULT_SA_TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
/ # curl -H "Authorization: Bearer $DEFAULT_SA_TOKEN" https://kubernetes/api/v1 --insecure
{
  "kind": "APIResourceList",
  "groupVersion": "v1",
  "resources": [
    {
      "name": "bindings",
      "singularName": "",
      "namespaced": true,
      "kind": "Binding",
      "verbs": [
        "create"
      ]
    },
    {
    ...
    ...
    ...
```

Using the default token ***curl*** can access the API server an retrieve some cluster information.
But **curl** is not allow to request information about pods using the default serviceaccount token.
```
/ # DEFAULT_SA_TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
/ # curl -H "Authorization: Bearer $DEFAULT_SA_TOKEN" https://kubernetes/api/v1/namespace/default/pods --insecure
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "namespace \"default\" is forbidden: User \"system:serviceaccount:default:default\" cannot get resource \"namespace/pods\" in API group \"\" at the cluster scope",
  "reason": "Forbidden",
  "details": {
    "name": "default",
    "kind": "namespace"
  },
  "code": 403
}
```
## Create a ServiceAccout
***mypod-sa***
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mypod-sa
```
```
# Create a Service Account
$ kubectl apply -f mypod-sa.yaml
serviceaccount/mypod-sa created

# Verifi the service account exists
$ kubectl get sa
NAME                 SECRETS   AGE
mypod-sa             1         5s
```

## Create a Role that allow curl to access the pods information
***mypod-role.yaml***
```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: mypod-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

```
$ kubectl apply -f mypod-role.yaml
role.rbac.authorization.k8s.io/mypod-role created

$ kubectl get roles
NAME         CREATED AT
mypod-role   2022-01-20T12:58:02Z
```
## Create RoleBinding
Create a bind between the service account used by the pod and the role that allow to list roles
***mypod-rolebinding.yaml***
```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mypod-rolebinding
  namespace: default
roleRef:
  kind: Role
  name: mypod-role
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: mypod-sa
    namespace: default
```
***Deploy***
```
$ kubectl apply -f mypod-rolebinding.yaml
rolebinding.rbac.authorization.k8s.io/mypod-rolebinding created

$ kubectl get rolebindings
NAME                ROLE              AGE
mypod-rolebinding   Role/mypod-role   9s

$ kubectl describe rolebindings
Name:         mypod-rolebinding
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  Role
  Name:  mypod-role
Subjects:
  Kind            Name      Namespace
  ----            ----      ---------
```
Now the service account mypod-sa and the role mypod-role are bound and the service account used in the pod.
The pod then can list PODs in the namespace default ( See RoleBinding and ClusterRoleBinding)
```
/ # DEFAULT_SA_TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
/ # curl -H "Authorization: Bearer $DEFAULT_SA_TOKEN" https://kubernetes/api/v1/namespaces/default/pods --insecure
{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "resourceVersion": "424463"
  },
  "items": [
    {
      "metadata": {
        "name": "new-mypod",
        "namespace": "default",
        "uid": "1e43d317-3ff9-49d4-863b-755c93dc5ff8",
        "resourceVersion": "424024",
        "creationTimestamp": "2022-01-20T15:28:34Z",
        "annotations": {
          "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{},\"name\":\"new-mypod\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"command\":[\"sleep\",\"3600\"],\"image
\":\"radial/busyboxplus\",\"name\":\"new-mybod\"}],\"serviceAccountName\":\"mypod-sa\"}}\n"
        },
...
...
 
```
