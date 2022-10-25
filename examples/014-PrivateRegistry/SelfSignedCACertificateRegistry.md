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
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
9TCnni9W1MBfvDQoXHB7ogje7Zvjsw==
-----END CERTIFICATE-----
---
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
Verification error: self signed certificate
---
New, TLSv1.2, Cipher is ECDHE-RSA-AES128-GCM-SHA256
Server public key is 4096 bit
Secure Renegotiation IS supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
SSL-Session:
    Protocol  : TLSv1.2
    Cipher    : ECDHE-RSA-AES128-GCM-SHA256
    Session-ID: 388EFAE1964A32267AEADFF443609BFB7CBE7E1FB0B6371B8CBA143C5287CB6D
    Session-ID-ctx:
    Master-Key: 35186DC74856E01FC1A1A9D1B8D0447870655EFE2A939C9E25C433BDB434041D86342CC108F8F5112CCD903F3BC4240F
    PSK identity: None
    PSK identity hint: None
    SRP username: None
    TLS session ticket:
    0000 - 79 35 1c 71 4e 40 08 8d-66 49 6e c0 63 46 7a 79   y5.qN@..fIn.cFzy
    0010 - ba f2 40 cc 55 a4 ac 04-04 f5 0f 06 e4 88 3b a7   ..@.U.........;.
    0020 - 7a 85 6f 9a 35 46 3c cd-ed 03 d5 24 33 18 9f 73   z.o.5F<....$3..s
    0030 - c7 51 f6 37 69 23 4c 8c-2f e8 30 95 7e 1c f7 40   .Q.7i#L./.0.~..@
    0040 - de ac b5 3b b7 1a 71 8c-91 2a 34 8a 0a 4b 15 02   ...;..q..*4..K..
    0050 - 18 bf a0 9f 90 cd 57 f2-6e 14 c4 55 13 2d b9 12   ......W.n..U.-..
    0060 - 4d a3 6c cd 24 b6 c2 6b-4d c1 cd 69 c6 27 d0 b6   M.l.$..kM..i.'..
    0070 - 20 02 0b d8 d8 78 7c 8d-                           ....x|.

    Start Time: 1666705361
    Timeout   : 7200 (sec)
    Verify return code: 18 (self signed certificate)
    Extended master secret: no
---
DONE
```

