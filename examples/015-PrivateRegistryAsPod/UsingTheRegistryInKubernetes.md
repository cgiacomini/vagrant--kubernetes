Allow all kubernetes node to access the docker-registry which run as a POD

## /etc/hosts
Update all nodes's ***/etc/hosts*** file to add docker-registry
se symply update the existing record for the k8s-master node as this

```
192.168.56.10  k8s-master.singleton.net k8s-master docker-registry
```

## Setup the docker client to trust the certificate
Here we instruct the docker client to trust the docker-registry self signed certificate.
```
$ sudo mkdir /etc/docker/certs.d/docker-registry:5000
$ sudo openssl s_client -showcerts -connect docker-registry:5000 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /tmp/cert.crt
$ sudo cp /tmp/cert.crt /etc/docker/certs.d/docker-registry:5000/
```

## Setup the system to trust the certificate
```
$ sudo cp /tmp/cert.crt /etc/pki/ca-trust/source/anchors/docker-registry.cert
$ sudo sudo update-ca-trust
```

## Query the catalog via REST API
We have no pushed any images yet so the repository is empty but accessible with no errors
```
$ curl   -u centos:centos  https://docker-registry:5000/v2/_catalog
{"repositories":[]}
```

## Create a docker-registry secret
Ref(https://jamesdefabia.github.io/docs/user-guide/kubectl/kubectl_create_secret_docker-registry/)
Normally to push/pull images to the registry we need to autenticate our self with the **docker login** command.  

In kubernetes when creating applications, in order for the nodes to pull images on your behalf, they have to have the credentials.
You can provide this information by creating a dockercfg secret and attaching it to your service account.
```
$ kubectl create secret docker-registry reg-secret --docker-server=docker-registry:5000 --docker-username=centos --docker-password=centos -n docker-registry
secret/reg-secret created

$ kubectl get secrets -n docker-registry
NAME          TYPE                             DATA   AGE
auth-secret   Opaque                           1      158m
cert-secret   kubernetes.io/tls                2      4h16m
reg-secret    kubernetes.io/dockerconfigjson   1      37s
```

## Try to push an immage to the registry

First we download a busybox image localy to our host using docker client command 
```
$ docker pull busybox
Using default tag: latest
latest: Pulling from library/busybox
22b70bddd3ac: Pull complete
Digest: sha256:125113b35efe765c89a8ed49593e719532318d26828c58e26b26dd7c4c28a673
Status: Downloaded newer image for busybox:latest
docker.io/library/busybox:latest

$ docker images
REPOSITORY                                 TAG       IMAGE ID       CREATED        SIZE
busybox                                    latest    bc01a3326866   6 hours ago    1.24MB

```
Now try to push in our docker-registry running as a POD.  
As usual we need to tag the image to refrence the POD docker registry

```
$ docker tag busybox:latest docker-registry:5000/busybox:v1
$ docker images
REPOSITORY                                 TAG       IMAGE ID       CREATED        SIZE
busybox                                    latest    bc01a3326866   6 hours ago    1.24MB
docker-registry:5000/busybox               v1        bc01a3326866   6 hours ago    1.24MB
```
and then to pull the image using the new references

```
$ docker push docker-registry:5000/busybox:v1
The push refers to repository [docker-registry:5000/busybox]
0438ade5aeea: Pushed
v1: digest: sha256:dacd1aa51e0b27c0e36c4981a7a8d9d8ec2c4a74bf125c0a44d0709497a522e9 size: 527

```

We now verify the catalog reports a new repostory on the docker-registry
```
$ curl   -u centos:centos  https://docker-registry:5000/v2/_catalog
{"repositories":["busybox"]}
```

## Try to create a new POD with the busybox image pulled from docker-registry 
For this to work we need to specify the secret to use to access the registry

```
$ kubectl run busybox-pod --image=docker-registry:5000/busybox:v1 -n docker-registry --overrides='{"apiVersion": "v1", "spec": {"imagePullSecrets": [{"name": "reg-secret"}]}}'
```



