# HELM
## Get latest release
Get and install the latest release on https://github.com/helm/helm/releases.  
Currently the latest helm release  is the 3.10.2
```
$ curl  --insecure https://get.helm.sh/helm-v3.10.2-windows-amd64.zip -OL
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 13.9M  100 13.9M    0     0  1841k      0  0:00:07  0:00:07 --:--:-- 4073k

$ unzip helm-v3.10.2-windows-amd64.zip
Archive:  helm-v3.10.2-windows-amd64.zip
   creating: windows-amd64/
  inflating: windows-amd64/helm.exe
  inflating: windows-amd64/LICENSE
  inflating: windows-amd64/README.md

# we are on cygwin here
$ cp helm.exe /usr/local/bin
```
Helm interacts directly with the Kubernetes API server therefor it needs to be able to connect to a Kubernetes cluster.  
As for ***kubectl*** command, Helm uses ***$HOME/.kube/config*** to find the required informations to connect to the cluster.  
It can also uses the **HELM_KUBECONTEXT** environment variable or the command line option **--kube-context** as an alterantive to locate the config file.

## Add a chart repository 
A chart repository is an HTTP server that houses collection of Kubernetes resource files.  
We can check this ArtifactoryHUB ("https://artifacthub.io/") to find what we want to install and then add its chart repository so helm can use it to download and install the chart.  
Here we use just one of the HelloWorld Charts available on the hub.  

```
# Add the chart repository
$ helm repo add hello-world https://ayazuddin007.github.io/Helm3/
"hello-world" has been added to your repositories

# list all added repository
$ helm repo list
NAME            URL
hello-world     https://ayazuddin007.github.io/Helm3/

# Search charts in the repository content
$ helm search repo hello-world
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
hello-world/hello-world 0.2.0           1.16.0          A Helm chart for Kubernetes
```

The repository contains one only chart that will install an hello world application.

## Install the chart
``
$ helm install my-hello-world hello-world/hello-world --version 0.2.0
NAME: my-hello-world
LAST DEPLOYED: Thu Dec  1 16:58:21 2022
NAMESPACE: ckad
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace ckad -l "app.kubernetes.io/name=hello-world,app.kubernetes.io/instance=my-hello-world" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace ckad $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace ckad port-forward $POD_NAME 8080:$CONTAINER_PORT

```
## Verify the installation
```
# the hello world application  has been deployed
$ k get pods -n ckad
NAMESPACE              NAME                                         READY   STATUS    RESTARTS       AGE
ckad                   my-hello-world-7dbfdb85f5-lb52k              1/1     Running   0              12s

# list the installed charts
$ helm list
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
my-hello-world  ckad            1               2022-12-01 16:58:21.7091025 +0100 CET   deployed        hello-world-0.2.0       1.16.0
```

## Test the application as explained by the install output
```
$ export POD_NAME=$(kubectl get pods --namespace ckad -l "app.kubernetes.io/name=hello-world,app.kubernetes.io/instance=my-hello-world" -o jsonpath="{.items[0].metadata.name}")
$ export CONTAINER_PORT=$(kubectl get pod --namespace ckad $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
$ echo "Visit http://127.0.0.1:8080 to use your application"
$ kubectl --namespace ckad port-forward $POD_NAME 8080:$CONTAINER_PORT &
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80

$ curl http://127.0.0.1:8080
Handling connection for 8080
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
## Customizing The Chart Templates
