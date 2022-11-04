# Secrets

There are several type of secrets

| Type       | Usage |
| ----------- | ----------- |
|Opaque| generic arbitrary user-defined data|
|kubernetes.io/service-account-token|service account token|
|kubernetes.io/dockercfg|serialized ~/.dockercfg file|
|kubernetes.io/dockerconfigjson|  serialized ~/.docker/config.json file|
|kubernetes.io/basic-auth|credentials for basic authentication|
|kubernetes.io/ssh-auth|credentials for SSH authentication|
|kubernetes.io/tls|data for a TLS client or server|
|bootstrap.kubernetes.io/token|bootstrap token data|

Secrets can be created in a similar way we can create ConfigMaps


### Create Secrets from a file containing variable setting.

### Example 1
```
# Create an ssh key we want to use inside a pod as a secret
$ ssh-keygen.exe -f  ./mysshkey
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in ./mysshkey
Your public key has been saved in ./mysshkey.pub
The key fingerprint is:
SHA256:Z3CnOge/vKcpFb4jFgFNAgLmr+1VBrMTG988gGqNn24 cgiacomini@NCEL94641
The key's randomart image is:
+---[RSA 3072]----+
|.o. ...o.        |
|o  .  o..        |
| .   * o. . .    |
|  . + O =o.o     |
|   = = +S*+.     |
|  + . = .*+      |
| . . +  ooo.     |
|  . oE  ++oo.    |
|   ... . o*=     |
+----[SHA256]-----+

$ ls 
mysshkey  mysshkey.pub

# Create  generic (Opaque) secret that contains our ssh key and the passphrase
$ kubectl create secret  generic mysecret --from-file=ssh-private-key=./mysshkey --from-literal=passphrase=mypassphrase
secret/mysecret created

# Check  the secret has been created
$ kubectl get secrets
NAME                  TYPE                                  DATA   AGE
mysecret              Opaque                                2      63s

# Check secret content
$ kubectl get secrets mysecret -o yaml
apiVersion: v1
data:
  passphrase: bXlwYXNzcGhyYXNl
  ssh-private-key: LS0tLS1CRUdJTiBPUEVOU1NIIFB.........
kind: Secret
metadata:
  creationTimestamp: "2022-01-18T16:16:08Z"
  name: mysecret
  namespace: default
  resourceVersion: "335108"
  uid: 5b17d407-174a-4846-a425-5178c94b6884
type: Opaque

```

# Create secrets with YAML file
It is also possible to create secrets using YAML file, in this case we have encode the secrets values in *base64*, using base64 command,
as for the below example:

```
# base64 username
echo -n centosuser  | base64 
Y2VudG9zdXNlcg==
 
# base64 password
echo -n thepassword | base64 
dGhlcGFzc3dvcmQ=
```

create the secret YAML file with the encoded values
***001-secret-example.yaml***

```
apiVersion: v1
data:
  user: Y2VudG9zdXNlcg==
  password: dGhlcGFzc3dvcmQ=
kind: Secret
metadata:
  name: secret-example
  namespace: default
type: Opaque

```

```
# Deploy the secret
$ kubectl apply -f 001-secret-example.yaml
secret/secret-example created

# Check the secret has been created
$ kubectl get secrets secret-example
NAME             TYPE     DATA   AGE
secret-example   Opaque   2      19s

# Get the secret as YAML
$ kubectl get secrets secret-example -o yaml
apiVersion: v1
data:
  password: dGhlcGFzc3dvcmQ=
  user: Y2VudG9zdXNlcg==
kind: Secret
metadata:
  creationTimestamp: "2022-01-18T16:32:13Z"
  name: secret-example
  namespace: default
  resourceVersion: "336578"
  uid: d8ee6e57-7b18-427a-8d40-4215cb013d6f
type: Opaque

# Get the decoded password
$ kubectl get secrets secret-example  --template={{.data.password}} | base64  -d
thepassword

# get the decoded user
$ kubectl get secrets secret-example  --template={{.data.user}} | base64  -d
centosuser

```
# Use the secret in a POD

### Example using secret in a POD
***001-pod-example.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name:  secret-pod-example
spec:
  containers:
  - name: pod-example
    image: k8s.gcr.io/busybox
    command: [ "/bin/sh", "-c", "watch -n 5 ls /etc/config/"]
    volumeMounts:
    - name: secret
      mountPath: /etc/config
  volumes:
  - name: secret
    secret:
       secretName: secret-example
```
# Deployment
```
# Deploy the POD
$ kubectl apply -f 001-pod-example.yaml
pod/secret-pod-example created

# Verify the POD is running
$ kubectl get pods
NAME       READY   STATUS    RESTARTS   AGE
secret-pod-example        1/1     Running   0               23s

# check the logs 
$ kubectl logs secret-pod-example 
Every 5s: ls /etc/config/                                   2022-01-19 14:22:47

password
user

# Verify the content of the user and password file
$ kubectl exec secret-pod-example -it -- /bin/sh
/ # cd /etc/config/
/ # cat password
thepassword
/ # cat user
centosuser
```

# Create secrets with variables
Secrets can be created and their values can be used to set PODs environment variables

```
# Create a secret from a litteral
$ kubectl create secret generic my-new-secret --from-literal=password=root

# Verify how the secret is created
$ kubectl get secret my-new-secret -o yaml
apiVersion: v1
data:
  password: cm9vdA==
kind: Secret
metadata:
  creationTimestamp: "2022-01-19T14:44:22Z"
  name: my-new-secret
  namespace: default
  resourceVersion: "377139"
  uid: 12aac36a-9b9e-4515-ac40-55be3ae3bdcf
type: Opaque
```
# Use the secret to set a POD environment variable
***002-pod-example.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name:  secret-pod-example2
spec:
  containers:
  - name: pod-example
    image: k8s.gcr.io/busybox
    command: [ "/bin/sh", "-c", "watch -n 5 echo $MY_ENV_PASSWORD"]
    env:
    - name: MY_ENV_PASSWORD
      valueFrom:
        secretKeyRef: 
          name: my-new-secret
          key: password
```
# Deploy the POD
```
kubectl apply -f 002-pod-example.yaml
pod/secret-pod-example2 created

$ kubectl get pods
NAME                  READY   STATUS    RESTARTS   AGE
secret-pod-example2   1/1     Running   0          9s


# check POD's logs
# kubectl logs secret-pod-example2 
Every 5s: echo root                                         2022-01-19 14:55:46

root
```
