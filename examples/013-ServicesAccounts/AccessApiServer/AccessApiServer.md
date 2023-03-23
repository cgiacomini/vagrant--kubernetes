## Get API Server Host and Port

## API Server Authentication/Authorization
By default, Kubernetes exposes its API via HTTPS.  
To invoke this API, the client requests needs implement the correct authentication and authorization.
There are two main authentication mechanisms we can use handle the API Server auth:

1) SSL Certificate-based auth, 
2) Token-based auth.

### SSL-Certificate-based Auth
The certificates used by the API Server is signed by a CA Certificate Autority.
The client certificate locates inside the ~/.minikube/profiles/minikube/client.crt.  
The client private key locates inside the ~/.minikube/profiles/minikube/client.key.  
We need to set client certificate and client key in the curl request to authenticate with API Server.

### 1) Retrieve kubernetes ca.crt and ca.key
These two required files can be retrieved from the master nodes at the following location:

* /etc/kubernetes/pki/ca.crt
* /etc/kubernetes/pki/ca.key

We need to retrieve them and store them making sure that ca.key ( the private key ) as the propre 600 rights.

### 2) Create client private key and generate a Certificate Signing Request (CSR) specifying a Commin Name (CN) that allows to identify the user. 
```
# Generate private key
$ openssl genrsa -out admin.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
......+++++
............................+++++
e is 65537 (0x010001)

# Geneteate a CSR
$ openssl req -new -key admin.key -subj "/CN=admin/O=system:masters" -out admin.csr

# Result 
# ls
admin.csr
admin.key

```
### 3) Sign the CSR using the Kubernetes cluster's CA key pair
```
$ openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -out admin.crt
Signature ok
subject=CN = admin, O = system:masters
Getting CA Private Key
```
Now we have a valid certificate signed by the same CA of the kubernetes cluster

### 4) Use curl to access the API server sing the signed certificate
```
$ curl --cacert ./ca.crt  --cert ./admin.crt --key ./admin.key https://192.168.56.10:6443/version
{
  "major": "1",
  "minor": "25",
  "gitVersion": "v1.25.3",
  "gitCommit": "434bfd82814af038ad94d62ebe59b133fcb50506",
  "gitTreeState": "clean",
  "buildDate": "2022-10-12T10:49:09Z",
  "goVersion": "go1.19.2",
  "compiler": "gc",
  "platform": "linux/amd64"
}

```

### 5) Use curl to access the API server /metrics to prove that it is instrumented to export prometheus metrics
```
$ /usr/bin/curl.exe  --cacert ./ca.crt  --cert ./admin.crt --key ./admin.key https://192.168.56.10:6443/metrics 
```
