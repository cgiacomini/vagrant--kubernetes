# Kube State Metrics
Kube State Metrics is a service that communicates with the Kubernetes API server to obtain information about all API objects such as deployments, pods, and DaemonSets.   
It essentially gives Kubernetes API object metrics that aren’t available via native Kubernetes monitoring components.  
Kube State Metrics allow to monitor for example:
* Nodes status, capacity such as CPU and memory usage.
* Pods status.
* Resources Requests and limits.
etc.

**Note:** This is quite outdated please see [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)

## Deployment 
```
$ kubectl apply -f ./kube-state-metrics-playbooks/

clusterrolebinding.rbac.authorization.k8s.io/kube-state-metrics created
clusterrole.rbac.authorization.k8s.io/kube-state-metrics created
deployment.apps/kube-state-metrics created
serviceaccount/kube-state-metrics created
service/kube-state-metrics created
```
# Verification
The service deployed is of type NodePort that expose port 30080 and 10081 for metrics and telemetry metrics.  
By targeting one of the kubernetes cluster node on the exposed ports we can retrieve the corresponding metrics

```
$ curl http://192.168.56.12:30081
<html>
             <head><title>Kube-State-Metrics Metrics Server</title></head>
             <body>
             <h1>Kube-State-Metrics Metrics</h1>
                         <ul>
             <li><a href='/metrics'>metrics</a></li>
                         </ul>
             </body>
             </html>

$ curl http://192.168.56.12:30081/metrics
...
# TYPE kube_persistentvolume_status_phase gauge
kube_persistentvolume_status_phase{persistentvolume="local-pv3",phase="Pending"} 0
kube_persistentvolume_status_phase{persistentvolume="local-pv3",phase="Available"} 0
kube_persistentvolume_status_phase{persistentvolume="local-pv3",phase="Bound"} 0
kube_persistentvolume_status_phase{persistentvolume="local-pv3",phase="Released"} 1
kube_persistentvolume_status_phase{persistentvolume="local-pv3",phase="Failed"} 0
kube_persistentvolume_status_phase{persistentvolume="local-pv3-redis7",phase="Pending"} 0
...

$ curl http://192.168.56.12:30080
<html>
             <head><title>Kube Metrics Server</title></head>
             <body>
             <h1>Kube Metrics</h1>
                         <ul>
             <li><a href='/metrics'>metrics</a></li>
             <li><a href='/healthz'>healthz</a></li>
                         </ul>
             </body>
             </html>

$ curl http://192.168.56.12:30080/healthz
OK

```
