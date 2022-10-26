## Registry server with a self signed certificate.

To better secure the registry access we could create a self signed certificate for our private docker registry.  
The certificate then need to be added to all hosts the will requires access the to our private registry.  
  
If we ask for the current installed certificate on our running private docker registry we see that there is none:
```
$ openssl s_client -showcerts -connect localhost:5000
CONNECTED(00000003)
no peer certificate available
No client certificate CA names sent
...
...
Verify return code: 0 (ok)
```
### Generate and deploy Self Signed Certificate with SAN
We use OpenSSL to generate a self signed certificate with SAN (Subject Alternative Name)  
The raeson to use SAN is because the registry could complain about the old style CN (common name) certificates
```
$ openssl req -nodes -x509 -sha256 -newkey rsa:4096 \
   -keyout registry_auth.key \
   -out registry_auth.crt \
   -days 356 \
   -subj "/C=FR/ST=Alpes Maritimes/L=Nice/O=SINGLETON/OU=R&D/CN=docker-registry"  \
   -addext "subjectAltName = DNS:localhost,DNS:centos8s-server,DNS:centos8s-server.singleton.net,IP:192.168.56.200"
Generating a RSA private key
.....................++++
................................................................................................++++
writing new private key to 'registry_auth.key
```
In case we want just to use an IP address, prefix it with IP: instead of DNS.    
We now have to copy the certificate in the directoty we used to mount as volume on the docker registry container.

```
$ sudo mkdir -p  /var/lib/docker-registry/certs
$ sudo cp registry_auth.key /var/lib/docker-registry/certs/
$ sudo cp registry_auth.crt /var/lib/docker-registry/certs/

# stop and restart the registry container with the certificate location information
$ docker stop registry
$ docker rm registry
$ docker run -d -p 443:443 \
    --name registry \
    --restart=always \
    -v /var/lib/docker-registry:/data \
    -e REGISTRY_AUTH=htpasswd \
    -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/data \
    -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
    -e REGISTRY_AUTH_HTPASSWD_PATH=/data/auth/registry.password \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/data/certs/registry_auth.crt \
    -e REGISTRY_HTTP_TLS_KEY=/data/certs/registry_auth.key \
    registry:2.7
```

Using this along with basic authentication requires to also trust the certificate into the OS cert store for some versions of docker.
```
$ sudo cp /var/lib/docker-registry/certs/registry_auth.crt /etc/pki/ca-trust/source/anchors
$ sudo update-ca-trust
```
If we now ask for the current installed certificate on our private docker registry we see that there is one:
```
$ openssl s_client -showcerts -connect 192.168.56.200:443 < /dev/null
CONNECTED(00000003)
Can't use SSL_get_servername
depth=0 C = FR, ST = Alpes Maritimes, L = Nice, O = SINGLETON, OU = R&D, CN = docker-registry
verify error:num=18:self signed certificate
verify return:1
depth=0 C = FR, ST = Alpes Maritimes, L = Nice, O = SINGLETON, OU = R&D, CN = docker-registry
verify return:1
---
Certificate chain
 0 s:C = FR, ST = Alpes Maritimes, L = Nice, O = SINGLETON, OU = R&D, CN = docker-registry
   i:C = FR, ST = Alpes Maritimes, L = Nice, O = SINGLETON, OU = R&D, CN = docker-registry
...
Server certificate
subject=C = FR, ST = Alpes Maritimes, L = Nice, O = SINGLETON, OU = R&D, CN = docker-registry
issuer=C = FR, ST = Alpes Maritimes, L = Nice, O = SINGLETON, OU = R&D, CN = docker-registry
---
No client certificate CA names sent
Peer signing digest: SHA256
Peer signature type: RSA
Server Temp Key: X25519, 253 bits
---
SSL handshake has read 2387 bytes and written 382 bytes
Verification: OK
...
...
    Timeout   : 7200 (sec)
    Verify return code: 18 (self signed certificate)
    Extended master secret: no
---
DONE
```
### Trying to login using external access
The docker client is not yet configure to trust the server docker registry generate certificate.   
Trying to login will rise a x509 certificate error.
```
$ docker login centos8s-server:443
$ docker login centos8s-server.singleton.net:443
$ docker login 192.168.56.200:443

# All return the following error
Error response from daemon: Get "https://192.168.56.200:443/v2/": x509: certificate signed by unknown authority
```

We assume now that we do not want to access to the registry only bye its FQDN (centos8s.singleton.net)  
We have then to instruct the docker client on all nodes to trust the certificate by coping it int the following directory:  
*/etc/docker/certs.d/<your_registry_host_name>:<your_registry_host_port>/*
```
# On all hosts
$ sudo mkdir /etc/docker/certs.d/centos8s-server.singleton.net:443
$ sudo openssl s_client -showcerts -connect centos8s-server.singleton.net:443 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /tmp/cert.crt
$ sudo cp /tmp/cert.crt /etc/pki/ca-trust/source/anchors/
$ sudo cp /tmp/cert.crt /etc/docker/certs.d/centos8s-server.singleton.net\:443
$ sudo sudo update-ca-trust
```
Now we can login using the FQDN Of the host runnig the local docker registry
```
$ docker login centos8s-server.singleton.net:443
Authenticating with existing credentials...
WARNING! Your password will be stored unencrypted in /home/centos/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```
### Pushing an image 
```
$ docker pull alpine:latest
$ docker tag  alpine:latest  centos8s-server.singleton.net:443/alpine
$ docker push centos8s-server.singleton.net:443/alpine
```
### Querying the registry
```
$ curl   -u centos:centos  https://centos8s-server.singleton.net:443/v2/_catalog
{"repositories":["alpine"]}
$ curl   -u centos:centos  https://centos8s-server.singleton.net:443/v2/alpine/tags/list
{"name":"alpine","tags":["latest"]}
```

# Run a POD with an image from the local docker registry

## Create a docker-registry secret

We first need to create a secret that will be used by all nodes pulling the image to autenticate theirself to the registry.  
Is the equivalent for kubernetes of a docker login ( see ref Ref(https://jamesdefabia.github.io/docs/user-guide/kubectl/kubectl_create_secret_docker-registry/)

```
$ kubectl create secret docker-registry  centos8s-server-secret --docker-server=centos8s-server.singleton.net:443 --docker-username=centos --docker-password=centos -n docker-registry
secret/reg-secret created

$ kubectl get secrets -n docker-registry
NAME                     TYPE                             DATA   AGE
centos8s-server-secret   kubernetes.io/dockerconfigjson   1      20m
```

## Pull an immage 

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
## Push the image to the local registry

Now try to push the image in our docker-registry running as a POD.
As usual we need to tag the image to refrence the docker registry

```
$ docker tag busybox centos8s-server.singleton.net:443/busybox
The push refers to repository [entos8s-server.singleton.net:443/busybox]
0438ade5aeea: Pushed

$ docker images 
REPOSITORY                                  TAG       IMAGE ID       CREATED        SIZE
centos8s-server.singleton.net:443/busybox   latest    bc01a3326866   7 hours ago    1.24MB
busybox                                     latest    bc01a3326866   7 hours ago    1.24MB

$ docker push centos8s-server.singleton.net:443/busybox
Using default tag: latest
The push refers to repository [centos8s-server.singleton.net:443/busybox]
0438ade5aeea: Pushed
```

We now verify the catalog reports a new repostory on the docker-registry
```
$ curl   -u centos:centos  https://centos8s-server.singleton.net:443/v2/_catalog
{"repositories":["busybox"]}
```

## Try to create a new POD with the busybox image pulled from docker-registry
For this to work we need to specify the secret to use to access the registry

```
$ kubectl run busybox-pod --image=centos8s-server.singleton.net:443/busybox -n docker-registry --overrides='{"apiVersion": "v1", "spec": {"imagePullSecrets": [{"name":  "centos8s-server-secret"}]}}' -- sleep 3600
pod/busybox-pod created

$ kubectl get pods -docker-registry
NAMESPACE              NAME                                         READY   STATUS      RESTARTS        AGE
docker-registry        busybox-pod                                  1/1     Running     0               6s
```
