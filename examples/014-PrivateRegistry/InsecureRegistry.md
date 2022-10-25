## insecure docker registry

### Starting the registry
A docker registry can be run as as a docker image by pulling the and running the official registry image from DockerHub.

```
docker run -p 5000:5000 -v /var/lib/docker-registry:/data \
    --name registry \
    -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/data \
    registry:2.7

# Verify we can connect to the registry and retrieve some info concerning existing images
curl http://localhost:5000/v2/_catalog
{"repositories":[]}

```

### Pushing an image

The first step is to have a valid image to be pushed to the new local registry.
We can achieve this by creating our one image by build one via a Dockerfile or simply
pulling one from DockerHub and then pushing it the our new local registry.

```
# Pulling a small docker image from DockerHub
$ docker pull alpine:latest
latest: Pulling from library/alpine
213ec9aee27d: Pull complete
Digest: sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad
Status: Downloaded newer image for alpine:latest
docker.io/library/alpine:latest

# Verify we now have the alpine image downloade
$ docker images
REPOSITORY                       TAG        IMAGE ID       CREATED         SIZE
alpine                           latest     9c6f07244728   2 months ago    5.54MB
registry                         2.7        b8604a3fe854   11 months ago   26.2MB

# Tag the alpine immage to be pushed in the local registry
$ docker tag alpine:latest localhost:5000/alpine

# Verify we have a new tag
$ docker images
REPOSITORY                       TAG        IMAGE ID       CREATED         SIZE
alpine                           latest     9c6f07244728   2 months ago    5.54MB
localhost:5000/alpine            latest     9c6f07244728   2 months ago    5.54MB
registry                         2.7        b8604a3fe854   11 months ago   26.2MB

# Push the image
$ docker push localhost:5000/alpine
Using default tag: latest
The push refers to repository [localhost:5000/alpine]
994393dc58e7: Pushed
latest: digest: sha256:1304f174557314a7ed9eddb4eab12fed12cb0cd9809e4c28f29af86979a3c870 size: 528

# Verify the local registry has the new image
$ curl localhost:5000/v2/_catalog
{"repositories":["alpine"]}
$ curl localhost:5000/v2/alpine/tags/list
{"name":"alpine","tags":["latest"]}
```

### Pulling the image

Now we can delete our alpine image and tag from docker and try to pull it back this time from
our local registry.

```
$ docker rmi alpine:latest
Untagged: alpine:latest
Untagged: alpine@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

$ docker rmi localhost:5000/alpine
Untagged: localhost:5000/alpine:latest
Untagged: localhost:5000/alpine@sha256:1304f174557314a7ed9eddb4eab12fed12cb0cd9809e4c28f29af86979a3c870
Deleted: sha256:9c6f0724472873bb50a2ae67a9e7adcb57673a183cea8b06eb778dca859181b5
Deleted: sha256:994393dc58e7931862558d06e46aa2bb17487044f670f310dffe1d24e4d1eec7

# Pull the alpine image from the local registry
$ docker pull localhost:5000/alpine
Using default tag: latest
latest: Pulling from alpine
213ec9aee27d: Pull complete

$ docker images
REPOSITORY                       TAG        IMAGE ID       CREATED         SIZE
localhost:5000/alpine            latest     9c6f07244728   2 months ago    5.54MB
registry                         2.7        b8604a3fe854   11 months ago   26.2MB
```
