# Installing Prometheus on Kubernetes
1. [Prepare NFS share](#PrepareNFSshare)
2. [Preparing the playbooks](#Preparingtheplaybooks)
    1. [Create Namespace monitoring](#CreateNamespacemonitoring))
    2. [Create Service Account Role and Role binding](#CreateServiceAccountRoleandRolebinding))
    3. [CreateConfigmap](#CreateConfigmap))
    4.  [Prometheus storage](#Prometheusstorage))
3. [Accessing Prometheus](#AccessingPrometheus)
4. [Prometheus deployment](#Prometheusdeployment)
5. [Using the prometheus Dashboard with NodePort Service](#UsingtheprometheusDashboardwithNodePortService)
6. [Using the prometheus Dashboard using the the ingress](#UsingtheprometheusDashboardusingthetheingress)

<a name="PrepareNFSshare"></a> ## Prepare NFS share
In this example the ***centos8s-server.singleton.net*** server, configured and used in [example-014-PriveRegistry](../014-PrivateRegistry/README.md)
will be configured to serve as NFS server. The NFS server will share a portion of its filesystem to all nodes of the couchbase cluster.
The shared folder will be used than to store Prometheus metrics. 
The NFS server and the nodes configuration procedure is described in [NFSServerCentos.md](./NFSServerCentos.md).  

The NFS share is mounted on all nodes in the ***/mnt/cluster_nfs*** mount point.
A dedicate directory to host prometheus metrics is created in the shared NFS on the NFS sever.

```
$ sudo mkdir -p /mnt/nfs_shares/cluster_nfs/Prometheus
$ sudo chown nobody:nobody /mnt/nfs_shares/cluster_nfs/Prometheus
$ sudo chmod ugo+rwx /mnt/nfs_shares/cluster_nfs/Prometheus
```
Now all nodes should have access in read/write access to the /mnt/cluster_nfs/Prometheus directory

<a name="Preparingtheplaybooks"></a> ## Preparing the playbooks
<a name="CreateNamespacemonitoring"></a> ### Create Namespace *monitoring*
As command line
```
$ kubectl create namespace monitoring
$ kubectl config set-context --current --namespace=monitoring
```
Or via manifest file
```
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
  name: monitoring
```
```
kubectl apply -f namespace.yaml
```
<a name="CreateServiceAccountRoleandRolebinding"></a>### Create Service Account, Role and Role binding
Prometheus uses Kubernetes APIs to read all the available metrics from Nodes, Pods, Deployments, etc.  
For this reason, we need to create an RBAC policy with read access to the required API groups and bind the policy to the monitoring namespace.
The following manifest file is used to create a ***ServiceAccount*** and bind it to a ***ClusterRole***.  

>***Note:***  
>>* A ***Role*** can only be used to grant access to resources within a single namespace while a ***ClusterRole*** is cluster-scoped.  
We create a ClusterRole and we assign to it specific permissions for different kind of resources.  
We add to it the permissions to *get*, *list* and *watch* nodes, services endpoints, pods, and ingresses and also to PersistentVolumes and PersistentVolumesClaims.  
>>* A RoleBinding grants permissions to a role in its namespace while a ClusterRoleBinding grants cluster-wide access.
>>* Since we purposely create our ServiceAccount in the monitoring namespace, is required to specify the namespace of the ServiceAccount when we refer to it while creating the ClusterRoleBinding to select it.
>>* Note: The API group “” (empty string) represents the core Kubernetes API.

***cluster_role.yaml***
```
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - persistentvolumes
  verbs: ["get", "list", "watch","create","delete"]
- apiGroups: [""]
  resources:
  - persistentvolumeclaim
  verbs: ["get", "list", "watch","update"]
- apiGroups: ["storage.k8s.io"]
  resources:
  - storageclasses
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
```
<a name="CreateConfigmap"></a>### Create Configmap
Prometheus's configuration is defined in ***prometheus.yaml*** file.   
All the alert rules for AlertManager are configured in ***prometheus.rules***.  
We will set up an AlertManager to handle all alerting from prometheus metrics.  
These two files will present inside the Prometheus container in ***/etc/prometheus*** location as 
* ***/etc/prometheus/prometheus.yaml*** 
* ***/etc/prometheus/prometheus.rules*** 

The ***scrape_configs*** section of the configmap describe a set of scrape jobs :
* ***kubernetes-apiservers***: It gets all the metrics from the API servers.
* ***kubernetes-nodes***: It collects all the kubernetes node metrics.
* ***kubernetes-pods***: All the pod metrics get discovered if the pod metadata is annotated with prometheus.io/scrape and prometheus.io/port annotations.
* ***kubernetes-cadvisor***: Collects all cAdvisor metrics.
* ***kubernetes-service-endpoints***: All the Service endpoints are scrapped if the service metadata is annotated with prometheus.io/scrape and prometheus.io/port annotations. It can be used for black-box monitoring.

***config_map.yaml***
```
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf
  labels:
    name: prometheus-server-conf
  namespace: monitoring
data:
  prometheus.rules: |-
    groups:
    - name: devopscube demo alert
      rules:
      - alert: High Pod Memory
        expr: sum(container_memory_usage_bytes) > 1
        for: 1m
        labels:
          severity: slack
        annotations:
          summary: High Memory Usage
  prometheus.yml: |-
    global:
      scrape_interval: 5s
      evaluation_interval: 5s
    rule_files:
      - /etc/prometheus/prometheus.rules
    alerting:
      alertmanagers:
      - scheme: http
        static_configs:
        - :
          - "aletargetsrtmanager.monitoring.svc:9093"
    scrape_configs:
      - job_name: 'node-exporter'
        ervubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_endpoints_name]
          regex: 'node-exporter'
          action: keep
      
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      - job_name: 'kubernetes-nodes'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics     
      
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
      
      - job_name: 'kube-state-metrics'
        static_configs:
          - targets: ['kube-state-metrics.kube-system.svc.cluster.local:8080']
      - job_name: 'kubernetes-cadvisor'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
      
      - job_name: 'kubernetes-service-endpoints'
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
          action: replace
          target_label: __scheme__
          regex: (https?)
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_name
```
<a name="Prometheusstorage"></a>### Prometheus storage
Prometheus needs a dedicated storage to store the scrapped data, here we have decided to use an NFS share for this purpose.  
Now there are four possible choices here:
1. Mount the NFS share as a volume inside the prometheus POD using ***hostPath*** type.
2. Mount the NFS share as a volume inside the prometheus POD using ***nfs*** type.
3. Mount the NFS share as a volume inside a persistentVolume using ***hostPath*** type.
4. Mount the NFS share as a volume inside a persistentVolume using ***nfs*** type.

***hostPath*** will work here because all node are mounting the NFS share.
For choices 3. and 4. the deployment  will have to use a persistentVolumeClaim.  

But if we want a dynamic storage provisioning then using a PV and a PVC is the choice.  
With ***Dynamic Storage Provisioning***, the Kubernetes Control Plane automatically allocate storage to containers when it detects that the container need it.  
The storage is selected based on the storage class required by the container requirements. The Control Plane create a PV and and attach it to the container.

* [Solution 1](./Storage-1st-Solution.md) - Mount the NFS share directly inside the prometheus POD using ***nfs*** 
* [Solution 2](./Storage-2nd-Solution.md) - Mount the NFS share as a volume inside a persistentVolume using ***nfs*** type.

<a name="AccessingPrometheus"></a>## Accessing Prometheus
* [Method 1](./NodePortService.md) - Access via Node Port Service
* [Method 2](./Ingress.md) - Create an Ingress

<a name="Prometheusdeployment"></a>## Prometheus deployment
$ kubectl apply -f namespace
$ kubectl apply -f cluster_role.yaml
$ kubectl apply -f config_map.yaml
$ kubectl apply -f deployment.yaml
$ kubectl apply -f service.yaml
$ kubectl apply -f ingress.yaml
```
<a name="UsingtheprometheusDashboardwithNodePortService"></a>## Using the prometheus Dashboard with NodePort Service
we can now access the prometheus dashboard using uno of the kubernetes node IP and the opened port  to target the  prometheus service.
for example:
```
http://192.168.56.11:30909/
```

##<a name="UsingtheprometheusDashboardusingthetheingress"></a>Using the prometheus Dashboard using the the ingress
Once the ingress is deployed we can access the prometheus Dashboard via the following URL : 
```
http://prometheus.singleton.net
```
