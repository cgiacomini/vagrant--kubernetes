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

## Create the Service to target the node exporter endpoints

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

$ kubectl get endpoints -n monitoring
NAME                         ENDPOINTS                       AGE
node-exporter                10.10.1.168:91,10.10.2.215:91   35s
prometheus-service-ingress   10.10.2.214:9090                13d

```
