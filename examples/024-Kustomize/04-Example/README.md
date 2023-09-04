# Helm and Kustomize together

## Initial Setup
We start by creating our own basic chart. Helm is helping us by creating a basic scheleton of a chart directory structures and files. 
We clould instead decide to pull our own chart from an helm repository for this examplem both options are good.
```
$ mkdir application/charts; cd application/charts
$ helm create helloworld
Creating helloworld
```

We end-up to have a directory structure like this:
```
$ tree helloworld/
helloworld/
├── Chart.yaml
├── charts
├── templates
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml

```

By defailt helm generate a complate example chart that deploy *nginx* in the current context. So make sure do be in the right namespace before trying to deploy it.
```
$ kubectl config view | grep namespace:
    namespace: sandbox

$ cd application/charts/helloworld
$ helm install --generate-name  .

NAME: chart-1693818407
LAST DEPLOYED: Mon Sep  4 11:06:47 2023
NAMESPACE: sandbox
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace sandbox -l "app.kubernetes.io/name=helloworld,app.kubernetes.io/instance=chart-1693818407" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace sandbox $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace sandbox port-forward $POD_NAME 8080:$CONTAINER_PORT

```

Helm has deployed an nginx POD ad also a service of type ClusterIP so we can only verify if the *nginx* pod is actually reasponding, from inside the cluster. 
To do so as usual we run a **curl** POD to query our helloworld POD running nginx.
```
$ k run curl --image=radial/busyboxplus:curl -i --tty

If you don't see a command prompt, try pressing enter.
[ root@curl:/ ]$ env
KUBERNETES_SERVICE_PORT=443
KUBERNETES_PORT=tcp://10.96.0.1:443
HOSTNAME=curl
SHLVL=1
HOME=/root
CHART_1693818407_HELLOWORLD_PORT_80_TCP=tcp://10.107.143.79:80
PS1=\[\033[40m\]\[\033[34m\][ \[\033[33m\]\u@\H:\[\033[32m\]\w\[\033[34m\] ]$\[\033[0m\]
ENV=/root/.bashrc
CHART_1693818407_HELLOWORLD_SERVICE_PORT_HTTP=80
TERM=xterm
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
CHART_1693818407_HELLOWORLD_SERVICE_HOST=10.107.143.79
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_PROTO=tcp
LS_COLORS=di=34:ln=35:so=32:pi=33:ex=1;40:bd=34;40:cd=34;40:su=0;40:sg=0;40:tw=0;40:ow=0;40:
CHART_1693818407_HELLOWORLD_PORT=tcp://10.107.143.79:80
CHART_1693818407_HELLOWORLD_SERVICE_PORT=80
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
CLICOLOR=1
PWD=/
KUBERNETES_SERVICE_HOST=10.96.0.1
CHART_1693818407_HELLOWORLD_PORT_80_TCP_ADDR=10.107.143.79
CHART_1693818407_HELLOWORLD_PORT_80_TCP_PORT=80
CHART_1693818407_HELLOWORLD_PORT_80_TCP_PROTO=tcp

[ root@curl:/ ]$ curl http://$CHART_1693818407_HELLOWORLD_PORT_80_TCP_ADDR
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

```

We have so far we have a fully deployable running helm chart. and we can delete the deployment.
```
$ helm list
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
chart-1693818407        sandbox         1               2023-09-04 11:06:47.7106277 +0200 CEST  deployed        helloworld-0.1.0        1.16.0

$ helm uninstall chart-1693818407
release "chart-1693818407" uninstalled

$ helm list
NAME    NAMESPACE       REVISION        UPDATED STATUS  CHART   APP VERSION
```

## Customization 

Now that we have a valid chart we just want to customize the deployment for two different environments **dev** and **prod**. We would like for example that in dev the **replicasCount** for our POD will be set to 1 while in **prod** we want this value to be 10.
We would like also to differentiate the **namespace**  names do by **dev** for development and **prod** for production.

He we create the kustomization directory structure and files the reffers and kustomize the *helloworld* chart.
```
$ cd application
$ mkdir dev
$ mkdir prod
```

### dev customization

***hellowordl.yaml***
```
replicaCount 1
```
***kustomize.yaml***
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

helmCharts:
  - name: helloworld
    releaseName: helloworld
    valuesFile: helloworld.yaml

helmGlobals:
   chartHome: ../charts

```

### prod customization

***hellowordl.yaml***
```
replicaCount 1
```
***kustomize.yaml***
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: prod

helmCharts:
  - name: helloworld
    releaseName: helloworld
    valuesFile: helloworld.yaml

helmGlobals:
   chartHome: ../charts

```


we will end up to have the following directory structure and files:
```
$ tree application
application
├── charts
│   └── helloworld
│       ├── Chart.yaml
│       ├── charts
│       ├── templates
│       │   ├── NOTES.txt
│       │   ├── _helpers.tpl
│       │   ├── deployment.yaml
│       │   ├── hpa.yaml
│       │   ├── ingress.yaml
│       │   ├── service.yaml
│       │   ├── serviceaccount.yaml
│       │   └── tests
│       │       └── test-connection.yaml
│       └── values.yaml
├── dev
│   ├── helloworld.yaml
│   └── kustomization.yaml
└── prod
    ├── helloworld.yaml
    └── kustomization.yaml
```

Now we can verify and see how the dev and prod customization will looks like : ( **note**: the use of the **--enable-helm** options)


```
$ kubectl kustomize application/dev/ --enable-helm

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/instance: helloworld
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: helloworld
    app.kubernetes.io/version: 1.16.0
    helm.sh/chart: helloworld-0.1.0
  name: helloworld
  namespace: dev
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/instance: helloworld
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: helloworld
    app.kubernetes.io/version: 1.16.0
    helm.sh/chart: helloworld-0.1.0
  name: helloworld
  namespace: dev
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: http
  selector:
    app.kubernetes.io/instance: helloworld
    app.kubernetes.io/name: helloworld
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/instance: helloworld
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: helloworld
    app.kubernetes.io/version: 1.16.0
    helm.sh/chart: helloworld-0.1.0
  name: helloworld
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: helloworld
      app.kubernetes.io/name: helloworld
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: helloworld
        app.kubernetes.io/name: helloworld
    spec:
      containers:
      - image: nginx:1.16.0
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            path: /
            port: http
        name: helloworld
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        readinessProbe:
          httpGet:
            path: /
            port: http
        resources: {}
        securityContext: {}
      securityContext: {}
      serviceAccountName: helloworld
---
apiVersion: v1
kind: Pod
metadata:
  annotations:
    helm.sh/hook: test
  labels:
    app.kubernetes.io/instance: helloworld
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: helloworld
    app.kubernetes.io/version: 1.16.0
    helm.sh/chart: helloworld-0.1.0
  name: helloworld-test-connection
  namespace: dev
spec:
  containers:
  - args:
    - helloworld:80
    command:
    - wget
    image: busybox
    name: wget
  restartPolicy: Never
```

The prod rendering will be the same with the differences in the namespace and the replicasCount values.


### Try to deploy for production
```

$ kubectl kustomize application/prod/ --enable-helm | kubectl apply -f -
serviceaccount/helloworld created
service/helloworld created
deployment.apps/helloworld created
pod/helloworld-test-connection created

$ kubectl get pods -n prod
NAME                          READY   STATUS    RESTARTS   AGE
helloworld-6d44b96795-6mpml   1/1     Running   0          13s
helloworld-6d44b96795-dmp29   1/1     Running   0          13s
helloworld-6d44b96795-dxdwq   1/1     Running   0          13s
helloworld-6d44b96795-glq4f   1/1     Running   0          13s
helloworld-6d44b96795-lmlhb   1/1     Running   0          13s
helloworld-6d44b96795-mv7hd   1/1     Running   0          13s
helloworld-6d44b96795-pz9s8   1/1     Running   0          13s
helloworld-6d44b96795-q8gw8   1/1     Running   0          13s
helloworld-6d44b96795-vzsjq   1/1     Running   0          13s
helloworld-6d44b96795-z6txp   1/1     Running   0          13s
helloworld-test-connection    1/1     Running   0          13s

```

As we can see in prod namespace we have 10 replicas deployed
