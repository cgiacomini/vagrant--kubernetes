# Create 1st example Chart

```
# Create 1st Chart project
$ helm create fruit

# Verify the created directory structure and generate templates files
$ tree fruits/
fruits/
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
By default the generated Chart is prepared to instanciate a deployment for a POD with an nginx image exposing port 80, and create a service to access the POD.  
The chart can be installed without any modifications by running the following command.
```
$ helm install myapp fruits

NAME: myapp
LAST DEPLOYED: Fri Dec  2 10:14:24 2022
NAMESPACE: ckad
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace ckad -l "app.kubernetes.io/name=fruits,app.kubernetes.io/instance=myapp" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace ckad $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace ckad port-forward $POD_NAME 8080:$CONTAINER_PORT

# Verify what has been deployed
$ k get all -n ckad
NAME                               READY   STATUS    RESTARTS   AGE
pod/myapp-fruits-786779d68-t9hfh   1/1     Running   0          3m7s

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/myapp-fruits   ClusterIP   10.100.32.119   <none>        80/TCP    3m7s

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/myapp-fruits   1/1     1            1           3m7s

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/myapp-fruits-786779d68   1         1         1       3m7s
```
Following the instruction given as output of the installation command we see we can access nginx from the host machine outside the cluster
```
$ export POD_NAME=$(kubectl get pods --namespace ckad -l "app.kubernetes.io/name=fruits,app.kubernetes.io/instance=myapp" -o jsonpath="{.items[0].metadata.name}")
$ export CONTAINER_PORT=$(kubectl get pod --namespace ckad $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
$ kubectl --namespace ckad port-forward $POD_NAME 8080:$CONTAINER_PORT
$ kubectl --namespace ckad port-forward $POD_NAME 8080:$CONTAINER_PORT &
[1] 537
$ Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80

# Try to access the application via the service
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

# Cleanup
$ kill %1
$ jobs
[1]+  Terminated              kubectl --namespace ckad port-forward $POD_NAME 8080:$CONTAINER_PORT


# List installed charts
$ helm list
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
myapp   ckad            1               2022-12-02 10:14:24.625087 +0100 CET    deployed        fruits-0.1.0    1.16.0

# Delete myapp installed chart
$ helm delete myapp
release "myapp" uninstalled

```
## Customize The Chart Templates
The generated ***fruits/values.yaml*** contains the default values for the chart, while the ***Chart.yaml*** contains the description of the Chart.
[ Ref. : https://helm.sh/docs/chart_template_guide/getting_started/ ]
