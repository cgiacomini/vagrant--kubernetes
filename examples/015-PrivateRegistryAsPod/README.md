# Provate Docker Registry As a POD

## Crearte a namespace ***docker-registry*** for our docker registry

We first create a namespace where we put all the registry resources

***docker-registry-namespace.yaml"***
```
apiVersion: v1
kind: Namespace
metadata:
  labels:
    kubernetes.io/metadata.name: docker-registry
  name: docker-registry
spec:
  finalizers:
  - kubernetes
status:
  phase: Active
```

## Generate a Self Signed Certificate with SAN

We use OpenSSL to generate a self signed certificate with SAN (Subject Alternative Name)

```
$ mkdir -p registry/certs
$ openssl req -nodes -x509 -sha256 -newkey rsa:4096 \
   -keyout registry_auth.key \
   -out registry/cets
   -days 356 \
   -subj "/C=FR/ST=Alpes Maritimes/L=Nice/O=SINGLETON/OU=R&D/CN=docker-registry"  \
   -addext "subjectAltName = DNS:docker-registry"
Generating a RSA private key
.....................++++
................................................................................................++++
writing new private key to 'registry_auth.key
```

### Create a TSL secret

We can do it easyly on a command line like this example

```
kubectl create secret tls my-tls-secret \
   --key <private key> \
   --cert <certificate> \
   -n docker-registry
```
Or we can create its own proper yaml file as follow.  
This way would be easier to reaply in case we need to do so.

```
--- 
apiVersion: v1
data: 
  tls.crt: "base64 encoded cert"
  tls.key: "base64 encoded key"
kind: Secret
metadata: 
  name: my-tls-secret
  namespace: docker-registry
type: kubernetes.io/tls
```

For this we though have to provide the certificate and the key in base64 encoded format.

```
$ cat registry/certs/registry_auth.crt | base64 -w 0
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUY0VENDQTh ....

$ cat registry/certs/registry_auth.key | base64 -w 0
LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUpRd0lCQUR ....
```

then we copy the base64 encoded certificate and key inside the yaml file ase this

***docker-registry-cert-secret.yaml***
```
---
apiVersion: v1
data:
  tls.crt: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUY0VENDQTh ...."
  tls.key: "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUpRd0lCQUR ...."
kind: Secret
metadata:
  name: cert-secret
  namespace: docker-registry
type: kubernetes.io/tls
```

Apply and verify that the secret has been created

```
$ kubectl apply -f docker-registry-cert-secret.yaml*
secret/docker-registry-secret created

$ kubectl get secrets -A
NAMESPACE              NAME                              TYPE                                  DATA   AGE
docker-registry        cert-secret                       kubernetes.io/tls                     2      7s
ingress-nginx          ingress-nginx-admission           Opaque                                3      7d12h
kubernetes-dashboard   admin-user-secret                 kubernetes.io/service-account-token   3      7d12h
kubernetes-dashboard   kubernetes-dashboard-certs        Opaque                                0      7d12h
kubernetes-dashboard   kubernetes-dashboard-csrf         Opaque                                1      7d12h
kubernetes-dashboard   kubernetes-dashboard-key-holder   Opaque                                2      7d12h

```


## Create base autentication secret
We create the secret from a password file create with htpassword command line

```
$ mkdir -p registry/auth
$ htpasswd -Bc registry/auth registry.password centos
$ New password:
$ Re-type new password:

$ kubectl create secret generic auth-secret -n docker-registry --from-file=registry/auth/registry.password
secret/auth-secret created

$ k get secrets -n docker-registry
NAME          TYPE                DATA   AGE
auth-secret   Opaque              1      21s
cert-secret   kubernetes.io/tls   2      98m

cgiacomini@NCEL94641 ~/GitHub/vagrant-kubernetes/examples/015-PrivateRegistryAsPod
$ k get secret -n docker-registry auth-secret -o yaml
apiVersion: v1
data:
  registry.password: Y2VudG9zOiQyeSQwNSRPU1ZPNXRDcGUyRWo4MkRMWGZkSlZ1UDRtcGxEelFCbUNoTFlNOXlhamNadmZVM1FvcTBUaQo=
kind: Secret
metadata:
  creationTimestamp: "2022-10-26T09:58:06Z"
  name: auth-secret
  namespace: docker-registry
  resourceVersion: "222629"
  uid: 3bd661aa-506e-4752-ac03-fe68d6ffdadd
type: Opaque

```

## Create a Persistent Volume and Persistent Volume Claim
The Persisten Volume will be used to store the images we wil push inside the repository. It define the type of storage we need. 
The HostPath is the cluster node local storage that will be mounted in the docker-registry POD as a volunme.
We request a size of 2 gigabyte and a ReadWriteOnce access mode, which means the volume can be mounted as read-write by a single Node.  

The PVC is used by PODs, in particular our docker-registry POD to request physical storage. Here the PVC claim all storage ( 2 gygabyte) provided by the PC.  

***docker-registry-pvc.yaml***
```
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: docker-registry-repo-pv
  namespace: docker-registry
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /var/lib/docker-registry/repository
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: docker-registry-repo-pvc
  namespace: docker-registry
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

```
$ kubectl apply -f docker-registry-pv.yaml
persistentvolume/docker-registry-repo-pv created
persistentvolumeclaim/docker-registry-repo-pvc created
```

## Create the docker registry POD
We would like that the registry always run on the same node so that to access it we always use the same IP address.  
If we simply apply the folowing yaml file the pod could be schedule on any of the cluster nodes an there fore the services
we use to access it will end up to have differen CLUSTER-IP each time we restart the registry.

To force the registry to run on the master node we nee to :
1. add a label on the master node  ei run-docker-registry=true  
2. add a nodeSelector property in the pod sepecification tell to select the node with the label run-docker-registry=true
3. add tolerations property to the taints on the master node.
4. give the docker-registry service fixed IP of the master node as EXTERNAL-IP property


Give the label the master node 
```
$ kubectl label node k8s-master run-docker-registry=true
```

***docker-registry-pod.yaml***
```
---
apiVersion: v1
kind: Pod
metadata:
  name: docker-registry
  namespace: docker-registry
  labels:
    app: registry
spec:
  nodeSelector:
   run-ingress-controller: "true"
  tolerations:
  - key: node-role.kubernetes.io/master
    operator: Equal
    effect: NoSchedule
  - key: node-role.kubernetes.io/control-plane
    operator: Equal
    effect: NoSchedule
  containers:
  - name: registry
    image: registry:2.7
    volumeMounts:
    - name: repository
      mountPath: "/var/lib/registry"
    - name: certificate
      mountPath: "/certs"
      readOnly: true
    - name: autentication
      mountPath: "/auth"
      readOnly: true
    env:
    - name: REGISTRY_AUTH
      value: "htpasswd"
    - name: REGISTRY_AUTH_HTPASSWD_REALM
      value: "Registry Realm"
    - name: REGISTRY_AUTH_HTPASSWD_PATH
      value: "/auth/registry.password"
    - name: REGISTRY_HTTP_TLS_CERTIFICATE
      value: "/certs/tls.crt"
    - name: REGISTRY_HTTP_TLS_KEY
      value: "/certs/tls.key"
  volumes:
  - name: repository
    persistentVolumeClaim:
      claimName: docker-registry-repo-pvc
  - name: certificate
    secret:
      secretName: cert-secret
  - name: autentication
    secret:
      secretName: auth-secret
```
Verify the registry is scheduled and running on the k8s-master node 
```
$ kubectl apply -f docker-registry-pod.yaml
pod/docker-registry created

$ k get pods -n docker-registry  -o wide
NAME              READY   STATUS    RESTARTS   AGE   IP           NODE         NOMINATED NODE   READINESS GATES
docker-registry   1/1     Running   0          51s   10.10.0.34   k8s-master   <none>           <none>
```

## Docker Registry Service
To access the docker-registry pod we need to create a service with the name we have given when creating the certificate (Common Name field) in this case ***docker-registry***.
The service expose the port 5000 which then target the pod port 5000

***docker-registry-svc.yaml***
```
---
apiVersion: v1
kind: Service
metadata:
  name: docker-registry
  namespace: docker-registry
spec:
  externalIPs:
  - 192.168.56.10
  selector:
    app: registry
  ports:
  - port: 5000
    targetPort: 5000
```

Apply the yaml file and verify the services has the EXTERNAL-IP address to be the static IP address of the k8s-master node
```
$ kubectl apply -f docker-registry-svc.yaml
service/docker-registry created

$ kubectl get service -n docker-registry
NAME              TYPE        CLUSTER-IP       EXTERNAL-IP     PORT(S)    AGE
docker-registry   ClusterIP   10.102.235.196   192.168.56.10   5000/TCP   13s

```

## Test the registry
We can now try to isse a docker login from any node outside the cluster.
To to so we first add the following line to the host **/etc/hosts** file so it can
resolve the docker-registry name to be the k8s-node IP address
***/et/hosts***

```
192.168.56.10  docker-registry.singleton.net docker-registry
```

### Try to login. 1st Try!
```
docker login docker-registry:5000 -u centos -p centos
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Error response from daemon: Get "https://docker-registry:5000/v2/": x509: certificate signed by unknown authority (possibly because of "crypto/rsa: verification error" while trying to verify candidate authority certificate "docker-registry")
```

This error is raised because the docker client does not trust the certificate sent by the docker registry and we have created previuosly.
To solve this we need to add the certificate inside the host docker directory where the docker client looks for certificates
We would need to run the following commands on all host that need to access the docker registry 

```
$ sudo mkdir /etc/docker/certs.d/docker-registry:5000
$ sudo openssl s_client -showcerts -connect docker-registry:5000 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /tmp/cert.crt
$ sudo cp /tmp/cert.crt /etc/docker/certs.d/docker-registry:5000/

```

### Try to login. 2nd Try!
Now docker login should work and we can push and pull images on it.
```
docker login docker-registry:5000 -u centos -p centos
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /home/centos/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

```
To be able to access the registry via the REST API we should make the host on wich we run the curl command to trust the self signed certificate the the docker-registry is using.
For that to work we add the certificate to the trusted certificates of the system.

```
$ sudo cp /tmp/cert.crt /etc/pki/ca-trust/source/anchors/docker-registry.cert
$ sudo sudo update-ca-trust
```

# Query the catalog via REST API
We have no pushed any images yet so the repository is empty but accessible with no errors
```
$ curl   -u centos:centos  https://docker-registry:5000/v2/_catalog
{"repositories":[]}
```


