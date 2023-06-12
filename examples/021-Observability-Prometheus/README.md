# Prometheus
1. [Architecture](./PrometheusArchicture.md#prometheus-architecture)
    1. [General](./PrometheusArchicture.md#General)
    2. [Client Libraries](./PrometheusArchicture.md#client-libraries)
    3. [Exporters](./PrometheusArchicture.md#exporters)
    4. [Service Discovery](./PrometheusArchicture.md#service-discovery)
    5. [Scraping](./PrometheusArchicture.md#scraping)
    6. [The Dashboard](./PrometheusArchicture.md#the-ashboard)
    7. [Rules and Alerts](./PrometheusArchicture.md#rules-and-alerts)
    8. [Alert Monitoring](./PrometheusArchicture.md#alert-monitoring)
2. [Prometheus Time Series Data - Data Types](./TimeSeriesData.md)
    1. [Metrics Name](./TimeSeriesData.md#metrics-name)
    2. [Metrics Labels](./TimeSeriesData.md#metrics-labels)
    3. [Metric Types](./TimeSeriesData.md#metrics-types)
        1. [Counter](./TimeSeriesData.md#counter)
        2. [Gauge](./TimeSeriesData.md#gauge)
        3. [Histogram](./TimeSeriesData.md#histogram)
        4. [Summary](./TimeSeriesData.md#summary)
 3. [PromSQL](./PromSQL.md#querying)
    1. [Selectors](./PromSQL.md#selectors)
        1. [Label Matching](./PromSQL.md#label-matching)
        2. [Range Vector Selector](./PromSQL.md#range-vector-selector)
        3. [Offset Modifier](./PromSQL.md#offset-modifier)
    2. [Query Operators](./PromSQL.md@query-operators)
        1. [Arithmetic Binary Operatos](./PromSQL.md#arithmetic-binary-operators)
        2. [Comparison Binary Operators](./PromSQL.md#comparison-binary-operators)
        3. [Logical Set Binary Operators](./PromSQL.md#logical-set-binary-operators)
        4. [Agregation Operators](./PromSQL.md#agregation-operators)
    3. [Query Functions](./PronSQL.md#query-functions)
    4. [HTTP API](./PromSQL.md#http-api)
    5. [Visualization](./Visualization/README.md)
       1. [Expression Browser](./Visualization/README.md#expression-browser)
       2. [Console Templates](./Visualization/README.md#console-templates)
       3. [Console Templates Graph Library](./Visualization/README.md#console-templates-graph-library)
4. [Kube State Metrics](././KubeStateMetrics/KubeStateMetrics.md)
    1. [Deployment](./KubeStateMetrics/KubeStateMetrics.md#Deployment)
    2. [Verification](./KubeStateMetrics/KubeStateMetrics.md#Verification)
5. [Monitoring Docker Daemon](./DockerExporter/README.md)
    1. [Configure Docker](./DockerExporter/README.md#configure-Docker)
    2. [Configure Prometheus](./DockerExporter/README.md#configure-prometheus)
6. [Monitoring Docker Containers (cAdvisor)](./DockerExporter/README.md)
    1. [Run cAdvisor as a Docker Container](./DockerExporter/README.md#run-cadvisor-as-a-docker-container)
    2. [Configure Prometheus for cAdvisor Metrics](./DockerExporter/README.md#configure-prometheus-for-cadvisor-Metrics)
7. [Recording Rules](./RecordingRules/RecordingRules.md)
    1. [Recording rules YAML file syntax](./RecordingRules/RecordingRules.md#recording-rules-YAML-file-syntax) 
8. [High Availability](./PrometheusHighAvailability.md)
9. [Security](./PrometheusSecurity.md)

# Installing Prometheus on Kubernetes
1. [Prepare NFS share](./README.md#prepare-nfs-share)
2. [Preparing the playbooks](./README.md#preparing-the-playbooks)
    1. [Create Namespace monitoring](./README.md#Create-Namespace-monitoring)
    2. [Create Service Account Role and Role binding](./README.md#create-service-account-role-and-role-binding)
    3. [CreateConfigmap](./README.md#Create-Configmap)
    4. [Prometheus storage](./README.md#prometheus-storage)
3. [Accessing Prometheus](./README.md#Accessing-Prometheus)
4. [Prometheus deployment](./README.md#Prometheus-deployment)
5. [Using the prometheus Dashboard with NodePort Service](./README.md#Using-the-prometheus-Dashboar-dwith-NodePort-Service)
6. [Using the prometheus Dashboard using the ingress](./README.md#Using-the-prometheus-Dashboard-using-the-ingress)
# Node Exporter
1. [Deploy NodeExporter on all Kubernetes nodes](./NodeExporter/NodeExporter.md#deploy-nodeexporter-on-all-kubernetes-nodes)
    1. [Create the DaemonSet YAML file Manifest](./NodeExporter/NodeExporter.md#create-the-daemonset-yaml-file-manifest)
    2. [Deploy the DaemonSet](./NodeExporter/NodeExporter.md#deploy-the-daemonset)
    3. [Create the Service to target the node exporter endpoint](./NodeExporter/NodeExporter.md#create-the-service-to-target-the-node-exporter-endpoint)
    4. [Deploy the service](./NodeExporter/NodeExporter.md#deploy-the-service)
# Monitoring Python Applications using Prometheus
1. [Example1v0](./Example1v0/README.md)
2. [Example1v1](./Example1v1/README.md)


## Prepare NFS share
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

## Preparing the playbooks
### Create Namespace *monitoring*
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
### Create Service Account, Role and Role binding
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
### Create Configmap
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

# Prometheus storage
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

## Accessing Prometheus
* [Method 1](./NodePortService.md) - Access via Node Port Service
* [Method 2](./Ingress.md) - Create an Ingress

## Prometheus deployment
```
$ kubectl apply -f namespace
$ kubectl apply -f cluster_role.yaml
$ kubectl apply -f config_map.yaml
$ kubectl apply -f deployment.yaml
$ kubectl apply -f service.yaml
$ kubectl apply -f ingress.yaml
```
## Using the prometheus Dashboard with NodePort Service
we can now access the prometheus dashboard using uno of the kubernetes node IP and the opened port  to target the  prometheus service.
for example:
```
http://192.168.56.11:30909/
```

## Using the prometheus Dashboard using the ingress
Once the ingress is deployed we can access the prometheus Dashboard via the following URL : 
```
http://prometheus.singleton.net
```
