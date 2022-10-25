## Registry server with basic security

Because we spacified localhost, so far there was no need to setup a secure registry server.  
The easier way to secure the registry is to use basic authentication via username and password.

### Installing htpasswd command
```
$ sudo dnf install httpd-tools

```
We can now create a password file called ***registry.password*** for a user named ***centos***

```
$ htpasswd -Bc registry.password centos
$ New password:
$ Re-type new password:

# Copy the password in the registry server mounted volume
$ sudo mkdir /var/lib/docker-registry/auth
$ sudo cp registry.password /var/lib/docker-registry/auth
```

We now restart the registry server with password authentication

```
# Stop previous running registry container
$ docker stop registry
$ docker rm registry

# Start the registry with password authentication
$ docker run -p 5000:5000 \
    --name registry \
    -v /var/lib/docker-registry:/data \
    -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/data \
    -e REGISTRY_AUTH=htpasswd \
    -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
    -e REGISTRY_AUTH_HTPASSWD_PATH=/data/auth/registry.password \
    registry:2.7
```

Trying to access the registry now will ask for authentication

```
$ curl  localhost:5000/v2/_catalog
{"errors":[{"code":"UNAUTHORIZED","message":"authentication required","detail":[{"Type":"registry","Class":"","Name":"catalog","Action":"*"}]}]}
```

***Note:*** The docker registry logs also report that the authorization credentials are invalid. This is because we haven't provided any with the curl command.

```
level=warning msg="error authorizing context: basic authentication challenge for realm "Registry Realm": invalid authorization credential"
```

Trying to pull an image from the refistry also gives authentication error

```
$ docker pull localhost:5000/alpine
Using default tag: latest
Error response from daemon: Head "http://localhost:5000/v2/alpine/manifests/latest": no basic auth credentials
```

We need to provide username and password to be able to access it and also to pull/push images from/to it.

***Note:*** The docker registry do not log anymore the UNAUTHORIZED error, but a warning in case of the docker login.   
This is because two GET requests are sent to the registry the first one with no authentication. ??

```
# Use URL API with credentials
$ curl -u centos:centos  localhost:5000/v2/_catalog
{"repositories":["alpine"]}

# Login to docker with credentials
$ docker login localhost:5000
Username: centos
Password:
WARNING! Your password will be stored unencrypted in /home/centos/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

# Now is possible to pull the image from the local registry.
$ docker pull localhost:5000/alpine
Using default tag: latest
latest: Pulling from alpine
213ec9aee27d: Pull complete
Digest: sha256:1304f174557314a7ed9eddb4eab12fed12cb0cd9809e4c28f29af86979a3c870
Status: Downloaded newer image for localhost:5000/alpine:latest
localhost:5000/alpine:latest
```

The same way we can try to access the registry from a remote host by specifying the FQDN or the IP address of the host running docker daemon.

```
curl -u centos:centos 192.168.56.200:5000/v2/_catalog
{"repositories":["alpine"]}

curl -u centos:centos centos8s-server.singleton.net:5000/v2/_catalog
{"repositories":["alpine"]}
```

But we cannot login to the docker registry from the remote host yet. This is because a TSL communication is required.  
To do so we need for example generate a self signed SSL certificate for our registry, and add it to the remote host.

```
docker login  192.168.56.200:5000
Username: centos
Password:
Error response from daemon: Get "https://192.168.56.200:5000/v2/": http: server gave HTTP response to HTTPS client
