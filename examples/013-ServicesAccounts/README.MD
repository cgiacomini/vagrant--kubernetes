# Services Account, Roles and Roles binding  

## Services Accounts
Any processes or applications in a container which resides within a POD
can access the cluster by getting authenticated to the API server,
using a service account.

* Services account are used for basic authentication, A service account provides an identity for processes that run in a Pod,
* Roles and Roles Binding are used for authorization
* By default every POD uses a default service account
* Every namespaces has a default service account called ***default***
* Services Accounts are bound to specific namespaces. 
Kubernetes API differentiate internal and external users.

As shown below, since Kubernetes 1.24.0 secrets are not generated automatically any longer when creating services account.  
The reason for this is to avoid never expiring tokens and avoid possible security issues.  
Now when a POD is created *kubelet* uses the *TokenRequest API* to generate a token specifically for that Pod, which is mounted as a projected volume.  
The token expires after an hour or when the Pod is deleted, whichever comes first.  
Kubelet renews the token at regular intervals so the Pod always has a valid token mounted.  
If you absolutely need a never-expiring token stored in a Secret, you can still get one by creating the Secret yourself and adding a special annotation. Kubernetes will then add the token to the Secret for you.

### list the deployed services accounts
```
$ kubectl get sa -A | grep default
NAMESPACE              NAME                                 SECRETS   AGE

default                default                              0         152d
docker-registry        default                              0         145d
ingress-nginx          default                              0         152d
kube-flannel           default                              0         152d
kube-node-lease        default                              0         152d
kube-public            default                              0         152d
kube-system            default                              0         152d
kubernetes-dashboard   default                              0         152d
```

### Default service account
```
$ kubectl get sa default -n default -o yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: default
```
As you see here no token is assigned to the service account 
```
$ kubectl describe serviceaccount default -n default
Name:                default
Namespace:           default
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>
```

## Create a POD
***mypod.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name:mypod
  namespace: default
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

**The created pod has mounted a volume that contains the required service account token and certificate to  access the API server.**
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

The curl fails because it tries to access the API but is not allowed.
An access token should be provided.
```
$ kuctl exec mypod -it -- /bin/sh
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

Using the default token ***curl*** can access the API server and retrieve some cluster information.
But **curl** is not allow to request information about pods using the default serviceaccount token.
```
$ kubectl exec mypod -it -- /bin/sh
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
## Create a ServiceAccount
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

## Deploy the POD which uses our Service Account
We redeploy the POD by specifying our new service account.
***new-mypod.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: new-mypod
  namespace: default
spec:
  serviceAccountName: mypod-sa
  containers:
  - name: new-mybod
    image: radial/busyboxplus
    command:
    - sleep
    - "3600"
```
```
$ kubectl apply -f new-mypod.yaml 
pod/new-mypod created
```

Now the service account mypod-sa and the role mypod-role are bound and the service account used in the pod.
The pod then can list PODs in the namespace default ( See RoleBinding and ClusterRoleBinding)
```
 $ kubectl exec new-mypod -it -- /bin/sh
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
