# Kustomize


***REF***:  [https://devopssec.fr/article/deploiements-k8s-avec-kustomize]

**In this simple example we use kustomize to simply add labesl and selector properties to the base resouces YAML files: deployment.yaml and service.yaml.**

**Kustomize** is a Kubernetes configuration transformation tool that enables you to customize untemplated YAML files, leaving the original files untouched.  
Kustomize can also generate resources such as ConfigMaps and Secrets from other representations.
Unlike *Helm*, it's not a templating tool, but really a config management tool.

If you have ever attempted to deploy your applications to different Kubernetes environments, 
chances are you have customized a Kubernetes configuration for each environment by copying 
the YAML files from your k8s resources and modifying them according to your needs for each environment.
This approach remains very tedious and repetitive because to integrate improvements you have to go through each environment.

To show the benefit of *Kustomize* we create a simple project without Kustomize and modify it later using it.
We need to create the following three manifest files :
  
##  Without Kustomize

### Create the namespace

namespace.yaml

```
apiVersion: v1
kind: Namespace
metadata:
  name: sandbox
spec:
  finalizers:
  - kubernetes
status:
  phase: Active
```
  
### deployment.yaml
```

apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-test-kustomize
  namespace: sandbox
spec:
  selector:
    matchLabels:
      app: http-test-kustomize
  template:
    metadata:
      labels:
        app: http-test-kustomize
    spec:
      containers:
      - name: http-test-kustomize
        image: nginx
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
```
  
### service.yaml
```
apiVersion: v1
kind: Service
metadata:
  name: http-test-kustomize
  namespace: sandbox
spec:
  ports:
    - name: http
      port: 8080
  selector:
    app: http-test-kustomize
```

### Deplyment of the application
```
$ k apply -f namespace.yaml
namespace/sandbox created

$ k apply -f deployment.yaml
deployment.apps/http-test-kustomize created

$ k apply -f service.yaml
service/http-test-kustomize created

$ kubectl get deployment -n sandbox
NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/http-test-kustomize   1/1     1            1           83s

$ kubectl get service -n sandbox
NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/http-test-kustomize   ClusterIP   10.109.189.93   <none>        8080/TCP   78s

```

Right now we just deploy an nginx POD and a service to access it inside the sandbox namespace. 
We now delete them and use kustomize tools.
```
$ kubectl delete -f service.yaml
service "http-test-kustomize" deleted

$ kubectl delete -f deployment.yaml
deployment.apps "http-test-kustomize" deleted

```
## Using Kustomize

To show how Kustomize could be used to deploy the same above application in a different way, we are going to delete the *Labels* ant *Selector* attributes from the the above YAML files:
### deployment.yaml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-test-kustomize
  namespace: sandbox
spec:
  template:
    spec:
      containers:
      - name: http-test-kustomize
        image: nginx
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
```
### service.yaml
```
apiVersion: v1
kind: Service
metadata:
  name: http-test-kustomize
  namespace: sandbox
spec:
  ports:
    - name: http
      port: 8080
```

The new version of these YAML file will be the base for our customization. 
Here then we use kustomize to handle the deleted *Labels* and *Selector* what we just need is a ***kustomize.yaml*** as follow:

### Kustomization.yaml 
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

commonLabels:
  app: http-test-kustomize

resources:
  - service.yaml
  - deployment.yaml
```

The above ***kustomization.yaml*** file make use of the **commonLables** Kustomize Feature which will add labels and selector to all specified resources. 
The resorces are the list of the YAML on which the customization should apply.
For a List of Kustomize Feature we can use on a Kustomization.yaml file have a look to the following documentation :[https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/](Kubernetes Kustomization)

### Apply the kustomization
To have a preview of what will be produced when apply the kustomization.yaml file we can use the following command:
```
$ kubectl kustomize  base

apiVersion: v1
kind: Service
metadata:
  labels:
    app: http-test-kustomize
  name: http-test-kustomize
  namespace: sandbox
spec:
  ports:
  - name: http
    port: 8080
  selector:
    app: http-test-kustomize
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: http-test-kustomize
  name: http-test-kustomize
  namespace: sandbox
spec:
  selector:
    matchLabels:
      app: http-test-kustomize
  template:
    metadata:
      labels:
        app: http-test-kustomize
    spec:
      containers:
      - image: nginx
        name: http-test-kustomize
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
```
As we can see the *Labels* and *Selector* are now been injected the original YAML files.

To deploy the application we need to use the kubectl option ``-k`` as follow
```
$ kubectl apply -k base
service/http-test-kustomize created
deployment.apps/http-test-kustomize created
```
