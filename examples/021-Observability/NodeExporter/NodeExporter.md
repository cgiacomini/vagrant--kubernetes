# Node Exporter
By default kubernets exposes metrics from the metrics server (Cluster Metrics) and Cadvisor metrics (Container metrics) but no metrics of the nodes are exposes.
Node exporter is an official Prometheus exporter for capturing all the Linux system-related metrics.  
It collects all the hardware and Operating System level metrics that are exposed by the kernel.  
Here we deploy the prometheus nodeExporter on all kubernetes nodes.

# Deploy NodeExporter on all Kubernetes nodes
1) Deploy node exporter on all the Kubernetes nodes as a daemonset.  
2) Daemonset makes sure one instance of node-exporter is running in all the nodes. It exposes all the node metrics on port 9100 on the /metrics endpoint.  
3) Create a service that listens on port 9100 and points to all the daemonset node exporter pods. We would be monitoring the service endpoints (Node exporter pods) from Prometheus using the endpoint job config.

## Create the DaemonSet YAML file Manifest
***node-exporter-daemonset.yaml***
```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: node-exporter
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: exporter
      app.kubernetes.io/name: node-exporter
  template:
    metadata:
      labels:
        app.kubernetes.io/component: exporter
        app.kubernetes.io/name: node-exporter
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Equal
        effect: NoSchedule
      containers:
      - args:
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        - --no-collector.wifi
        - --no-collector.hwmon
        - --collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)
        - --collector.netclass.ignored-devices=^(veth.*)$
        name: node-exporter
        image: prom/node-exporter
        ports:
          - containerPort: 9100
            protocol: TCP
        resources:
          limits:
            cpu: 250m
            memory: 180Mi
          requests:
            cpu: 102m
            memory: 180Mi
        volumeMounts:
        - mountPath: /host/sys
          mountPropagation: HostToContainer
          name: sys
          readOnly: true
        - mountPath: /host/root
          mountPropagation: HostToContainer
          name: root
          readOnly: true
      volumes:
      - hostPath:
          path: /sys
        name: sys
      - hostPath:
          path: /
        name: root
```
## Deploy the DaemonSet
```
$ kubectl create -f node-exporter-daemonset.yaml

$ kubectl  get pods -n monitoring -o wide
NAME                                     READY   STATUS    RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
node-exporter-884cb                      1/1     Running   0          60s   10.10.2.215   k8s-node2   <none>           <none>
node-exporter-c4lhm                      1/1     Running   0          60s   10.10.1.168   k8s-node1   <none>           <none>
prometheus-deployment-847b77bd49-sz4tp   1/1     Running   0          8m    10.10.2.214   k8s-node2   <none>           <none
```

***Note:*** We have added toleration to allow the node exporter to be scheduled also on the master node.

## Create the  Service to target the node exporter endpoints

***node-exporter-service.yaml***
```
---
kind: Service
apiVersion: v1
metadata:
  name: node-exporter
  namespace: monitoring
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/port:   '9100'
spec:
  selector:
      app.kubernetes.io/component: exporter
      app.kubernetes.io/name: node-exporter
  ports:
  - name: node-exporter
    protocol: TCP
    port: 9100
    targetPort: 9100
```

## Deploy the service
```
$ kubectl apply  -f node-exporter-service.yaml
service/node-exporter created

$ kubectl get svc
NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
node-exporter                ClusterIP   10.105.240.50   <none>        9100/TCP         15m
prometheus-service           NodePort    10.103.162.88   <none>        8080:30909/TCP   34m
prometheus-service-ingress   ClusterIP   10.110.95.79    <none>        9090/TCP         76d

$ kubectl get endpoints -n monitoring
NAME                         ENDPOINTS                       AGE
node-exporter                10.10.1.168:91,10.10.2.215:91   35s
prometheus-service-ingress   10.10.2.214:9090                13d
```
## Verify the exporter metrics
We can now verify that by targeting the **node-exporter** service IP and PORT from a POD inside the cluster we can retrieve metrics
```
$ kubectl exec curl -it -- /bin/sh
[ root@curl:/ ]$ curl http://10.110.95.79:9090/metrics

# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 1.9418e-05
go_gc_duration_seconds{quantile="0.25"} 5.6237e-05
go_gc_duration_seconds{quantile="0.5"} 7.3011e-05
go_gc_duration_seconds{quantile="0.75"} 0.000112082
go_gc_duration_seconds{quantile="1"} 0.000574484
go_gc_duration_seconds_sum 0.01793755
go_gc_duration_seconds_count 182
...
...
```

## Node-exporter Prometheus Config
We need now to instruct prometheus on how to scrape the node exporter metrics.  
To do so, we need to change the prometheus configmap by adding a job in the *scrap_configs* section.
***node-exporter-prometheus-configmap.yaml***
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
      scrape_interval: 5s # default is every 1 minute
      scrape_timeout: 5s # default 10s
      evaluation_interval: 5s  # default is every 1 minute How frequently to evaluate rules
    rule_files:
      - /etc/prometheus/prometheus.rules
    alerting:
      alertmanagers:
      - scheme: http
        static_configs:
        - targets:
          - "aletargetsrtmanager.monitoring.svc:9093"
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets:
             - localhost:9090

      - job_name: node-exporter
        kubernetes_sd_configs:
           - role: endpoints
        relabel_configs:
           - source_labels: [__meta_kubernetes_endpoints_name]
             regex: node-exporter
             action: keep
```
Here we tell prometheus we are interested to scrape kubernetes endpoints whose names math the regular expression *node-exporter*.   
```
# Deploy the new configmap
$ kubectl apply -f node-exporter-prometheus-configmap.yaml
configmap/prometheus-server-conf configured
```
Using the Prometheus ingress we can now verify that prometheus is also exporting node-exporter metrics.
Here Using REST API we get all nodes CPU usage metrics
```
$ curl  http://prometheus.singleton.net/api/v1/query?query=node_cpu_seconds_total
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.0.78:9100","job":"node-exporter","mode":"idle"},"value":[1684923217.796,"7487.64"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.0.78:9100","job":"node-exporter","mode":"iowait"},"value":[1684923217.796,"20.71"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.0.78:9100","job":"node-exporter","mode":"irq"},"value":[1684923217.796,"221.76"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.0.78:9100","job":"node-exporter","mode":"nice"},"value":[1684923217.796,"19.21"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.0.78:9100","job":"node-exporter","mode":"softirq"},"value":[1684923217.796,"59.89"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.0.78:9100","job":"node-exporter","mode":"steal"},"value":[1684923217.796,"0"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.0.78:9100","job":"node-exporter","mode":"system"},"value":[1684923217.796,"332"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.0.78:9100","job":"node-exporter","mode":"user"},"value":[1684923217.796,"515.29"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.1.245:9100","job":"node-exporter","mode":"idle"},"value":[1684923217.796,"8447.07"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.1.245:9100","job":"node-exporter","mode":"iowait"},"value":[1684923217.796,"4.64"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.1.245:9100","job":"node-exporter","mode":"irq"},"value":[1684923217.796,"67.17"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.1.245:9100","job":"node-exporter","mode":"nice"},"value":[1684923217.796,"0.97"]},{"metric":{"__name__":"node_cpu_seconds_total","cpu":"0","instance":"10.10.1.245:9100","job":"node-exporter","mode":"softirq"},"value":[1684923217.796,"18.16"]},{"metric":
...
...
```
The same query can be issued on the Prometheus dashboard to obtain a grafical rapresentation.
We can example run the following queries on the dashboard:
```
node_memory_MemFree_bytes
node_cpu_seconds_total
node_filesystem_avail_bytes
rate(node_cpu_seconds_total{mode="system"}[1m]) 
rate(node_network_receive_bytes_total[1m])
```
