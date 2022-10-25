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
$ sudo mkdir /etc/docker/certs.d/centos8s-server.singleton.net:443
$ sudo cp 
$ sudo cp /var/lib/docker-registry/certs/registry_auth.crt  /etc/docker/certs.d/centos8s-server.singleton.net\:443/
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

