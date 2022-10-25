## Registry server with a self signed certificate.

To better secure the registry access we could create a self signed certificate for our private docker registry.
The certificate then need to be added to all hosts the will requires access the to our private registry.

We use OpenSSL to generate a self signed certificate with SAN (Subject Alternative Name)
The raeson to use SAN is because the registry could complain about the old style CN (common name) certificates.

If we ask for the current installed certificate on our private docker registry we see that there is none:
```
 openssl s_client -showcerts -connect localhost:5000
CONNECTED(00000003)
139811634358080:error:1408F10B:SSL routines:ssl3_get_record:wrong version number:ssl/record/ssl3_record.c:332:
---
no peer certificate available
---
No client certificate CA names sent
---
SSL handshake has read 5 bytes and written 289 bytes
Verification: OK
---
New, (NONE), Cipher is (NONE)
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 0 (ok)
```

### Generate Self Signed Certificate with SAN
```
$ openssl req -nodes -x509 -sha256 -newkey rsa:4096 \
   -keyout registry_auth.key \
   -out registry_auth.crt \
   -days 356 \
   -subj "/C=FR/ST=Alpes Maritimes/L=Nice/O=SINGLETON/OU=R&D/CN=docker-registry"  \
   -addext "subjectAltName = DNS:localhost,DNS:cents8s-server,DNS:centos8s-server.singleton.net,IP:192.168.56.200"
Generating a RSA private key
.....................++++
................................................................................................++++
writing new private key to 'registry_auth.key
```
In case we want just to use an IP address, prefix it with IP: instead of DNS.  
We now have to copy the certificate in the directoty we used to mount as volume on the docker registry container

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
If we ask for the current installed certificate on our private docker registry we see that there is one:
```
openssl s_client -showcerts -connect 192.168.56.200:443 < /dev/null
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
-----BEGIN CERTIFICATE-----
...
...
9TCnni9W1MBfvDQoXHB7ogje7Zvjsw==
-----END CERTIFICATE-----
---
Server certificate
subject=C = FR, ST = Alpes Maritimes, L = Nice, O = SINGLETON, OU = R&D, CN = docker-registry

issuer=C = FR, ST = Alpes Maritimes, L = Nice, O = SINGLETON, OU = R&D, CN = docker-registry

---
No client certificate CA names sent
...
...
    Timeout   : 7200 (sec)
    Verify return code: 18 (self signed certificate)
    Extended master secret: no
---
DONE
```

### Trying to login
Now the registry is running with a self signed certificate but we cannot yet login 
```
$ docker login centos8s-server:443
Error response from daemon: Get "https://192.168.56.200:443/v2/": x509: certificate signed by unknown authority
```

we must instruct docker to trust the self-signed certificate by copying the self-signed certificate to
/etc/docker/certs.d/<your_registry_host_name>:<your_registry_host_port>/
```
$ sudo mkdir -p /etc/docker/certs.d/192.168.56.200:5000
$ sudo mkdir -p /etc/docker/certs.d/192.168.56.200:443
$ sudo cp /var/lib/docker-registry/certs/registry_auth.crt /etc/docker/certs.d/192.168.56.200:5000
$ sudo cp /var/lib/docker-registry/certs/registry_auth.crt /etc/docker/certs.d/192.168.56.200:443


