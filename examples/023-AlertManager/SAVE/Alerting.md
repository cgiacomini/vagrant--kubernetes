# Alerting
## Alert Manager
The alert manager is a separate opensource process that works with prometheus server.  
Is responsible for handling alerts sent to it by clients such Prometheus server.  
Alerts are sent as notification to the alert manager and triggered automatically by metric data.

What the Alert manager does:
* deduplicate alerts when multiple clients send the same alert.
* group multiple alert together when they appen around the same time.
* route the alerts to the right receiver destination: email or other alerting application such as PagerDuty, or OpsGenie.
* it also takes care of silencing and inhibition of alerts by muting them for a given time.

The Alert Manager **does not** create alerts and **does not** determine when alerts needs to be sent based on metrics data.   
Prometheus instead is in charge of that and forward the alerts to the alert manager.

## Promethues configuration
Prometheues should be alredy configured to use the correct service manager service endpoint. 
When deployed prometheus in kubernetes this should be already the case but better check that prometheus configmap as the following lines in ***prometheus.yaml***  
```
    rule_files:
      - /etc/prometheus/prometheus.rules
    alerting:
      alertmanagers:
      - scheme: http
        static_configs:
        - targets:
          - "alertmanager.monitoring.svc.cluster.local:9093"
```

Note that in the prometheus configmap, ***prometheus.rules*** alredy have a demo alerting rules configured:
```
    - name: devopscube demo alert
      rules:
      - alert: High Pod Memory
        expr: sum(container_memory_usage_bytes) > 1
        for: 1m
        labels:
          severity: slack
        annotations:
          summary: High Memory Usage
```

## Deploy Alert Manager

### NFS shared folder for persisten data
The Alert Manager installation consist of :
* A config map for AlertManager configuration
* A config Map for AlertManager alert templates
* Alert Manager Kubernetes Deployment
* Alert Manager service and to access the web UI.

We deploy the Alert Managere in the same Prometheus namespace: ***monitoring***

Alert Manager need a local directory where it can store some data. As we did for prometheus and grafana we setup a PV and PVC to be used by the Alert Manager.  
On the NFS server:
```
$ cd /mnt/nfs_shares/cluster_nfs/
$ ll
total 4
drwxrwxrwx 6 nobody nobody   77 Jun  1 14:08 Grafana
drwxrwxrwx 8 nobody nobody 4096 Jun  1 13:00 Prometheus

# Create the directory for the alert manager
$ sudo mkdir AlertManager
$ sudo chown nobody.nobody AlertManager
$ sudo chmod 777  AlertManager

# Verification
$ ll
total 4
drwxrwxrwx 2 nobody nobody    6 Jun  1 14:12 AlertManager
drwxrwxrwx 6 nobody nobody   77 Jun  1 14:08 Grafana
drwxrwxrwx 8 nobody nobody 4096 Jun  1 13:00 Prometheus
```

### Deploy the PV and PVC

***AlertManagerStorage.yaml***
```
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: alert-manager-pv
  namespace: monitoring
  labels:
    app: alert-manager-deployment
spec:
  storageClassName: nfs-storageclass
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: centos8s-server.singleton.net
    path: /mnt/nfs_shares/cluster_nfs/AlertManager
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: alert-manager-pvc
  namespace: monitoring
  labels:
    app: alert-manager-deployment
spec:
  storageClassName: nfs-storageclass
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
```

```
$ kubectl apply -f AlertManagerStorage.yaml
persistentvolume/alert-manager-pv created
persistentvolumeclaim/alert-manager-pvc created

$ kubectl get pv
NAME                      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                                      STORAGECLASS       REASON   AGE
alert-manager-pv          1Gi        RWX            Retain           Bound      monitoring/alert-manager-pvc               nfs-storageclass            6s
grafana-pv                1Gi        RWX            Retain           Bound      monitoring/grafana-pvc                     nfs-storageclass            2d17h
prometheus-pv             1Gi        RWX            Retain           Bound      monitoring/prometheus-pvc                  nfs-storageclass            85d

$ kubectl get pvc
NAME                STATUS   VOLUME             CAPACITY   ACCESS MODES   STORAGECLASS       AGE
alert-manager-pvc   Bound    alert-manager-pv   1Gi        RWX            nfs-storageclass   22s
grafana-pvc         Bound    grafana-pv         1Gi        RWX            nfs-storageclass   2d17h
prometheus-pvc      Bound    prometheus-pv      1Gi        RWX            nfs-storageclass   85d

```

### Alert Manager Configmap
Here we configure the Alertmanager to send us mails whenever an alert reaches the firing state.

***AlertManagerConfigMap.yaml***

```
kind: ConfigMap
apiVersion: v1
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  config.yml: |-
    global:
    templates:
    - '/etc/alertmanager-templates/*.tmpl'
    route:
      receiver: alert-emailer
      group_by: ['alertname']
      group_wait: 10s
      repeat_interval: 30m
    receivers:
    - name: alert-emailer
      email_configs:
      - to: receiver_email_id@gmail.com
        from: 'email_id@gmail.com'
        smarthost: smtp.gmail.com:587
        auth_username: 'email_id@gmail.com'
        auth_identity: 'email_id@gmail.com'
        auth_password: 'password'
        headers:
           subject: '{{ template "custom_mail_subject" . }}'
        html: '{{ template "custom_mail_html" . }}'
    inhibit_rules:
      - source_match:
          severity: 'critical'
        target_match:
          severity: 'warning'
        equal: ['alertname', 'dev', 'instance']
```

In the above config map we need to adde our own email_id and password and also the recipient email address.  
We use google email SMTP server to send emails here.

We need ***alert templates*** for all the receivers we use (email, Slack, etc).   
Alert manager will dynamically substitute the values and deliver alerts to the receivers based on the template.   
You can customize these templates based on your needs.

Here is an example of a custm template for the subject and the body of the alert email.  

### Alert Manager ConfigMap for Alert templates

As you can see the Alertmanager config map refers to subject and html body template. These are defined in the template file
this template to define the *subject*  and the *body* contents.

***AlertTemplateConfigMap.yaml***

```
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: alertmanager-templates
  namespace: monitoring
data:
  my_custom_email.tmpl: |
    {{ define "custom_mail_subject" }}Alert on {{ range .Alerts.Firing }}{{ .Labels.instance }} {{ end }}{{ end }}
    {{ define "custom_mail_html" }}
    <html>
    <head>
    <title>Alert!</title>
    </head>
    <body>
    {{ range .Alerts.Firing }}

    <p>{{ .Labels.alertname }} on {{ .Labels.instance }}<br/>
    {{ if ne .Annotations.summary "" }}{{ .Annotations.summary }}{{ end }}</p>

    <p>Details:</p>

    <p>
    {{ range .Annotations.SortedPairs }}
      {{ .Name }} = {{ .Value }}<br/>
    {{ end }}
    </p>

    <p>
    {{ range .Labels.SortedPairs }}
      {{ .Name }} = {{ .Value }}<br/>
    {{ end }}
    </p>

    {{ end }}

    </body></html>
    {{ end }}

```

### Alert Manager Deployment

In the Deployment file *args* section we specify the location of the config file and the path thet the Alertmanager can use for internal storage which is where we mount our PV as NFS.
We also mount the configuratio volumes int dedicate place.


***AlertManagerDeployment.yaml***

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      name: alertmanager
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:latest
        args:
          - "--config.file=/etc/alertmanager/config.yml"
          - "--storage.path=/alertmanager"
        ports:
        - name: alertmanager
          containerPort: 9093
        resources:
            requests:
              cpu: 500m
              memory: 500M
            limits:
              cpu: 1
              memory: 1Gi
        volumeMounts:
        - name: config-volume
          mountPath: /etc/alertmanager
        - name: templates-volume
          mountPath: /etc/alertmanager-templates
        - name: alertmanager-storage-volume
          mountPath: /alertmanager
      volumes:
      - name: config-volume
        configMap:
          name: alertmanager-config
      - name: templates-volume
        configMap:
          name: alertmanager-templates
      - name: alertmanager-storage-volume
        nfs:
          server: centos8s-server.singleton.net
          path: /mnt/nfs_shares/cluster_nfs/AlertManager
```

### Alert Manager service

For now, for semplicity, we use a NodePort Service to reachout the alertmanager export. 

```
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: monitoring
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/port:   '9093'
spec:
  selector:
    app: alertmanager
  type: NodePort
  ports:
    - port: 9093
      targetPort: 9093
      nodePort: 31000
```


### Deployment and Verification
```
# Deploy all resources

$ kubectl apply -f alert-manager-playbooks/
configmap/alertmanager-config created
deployment.apps/alertmanager created
service/alertmanager created
persistentvolume/alert-manager-pv unchanged
persistentvolumeclaim/alert-manager-pvc unchanged
configmap/alertmanager-templates created
configmap/prometheus-server-conf configured

# Verify alert manager POD is running

$ k get pods
NAME                                     READY   STATUS    RESTARTS       AGE
alertmanager-7fc44b6977-g88g4            1/1     Running   0              80s
...
...

# Verify we can communicate with the alert manager using the node port service

$ curl http://192.168.56.10:31000/
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
        <link rel="icon" type="image/x-icon" href="favicon.ico" />
        <title>Alertmanager</title>
    </head>
    <body>
        <script>
            // If there is no trailing slash at the end of the path in the url,
            // add one. This ensures assets like script.js are loaded properly
            if (location.pathname.substr(-1) != '/') {
                location.pathname = location.pathname + '/';
                console.log('added slash');
            }
        </script>
        <script src="script.js"></script>
        <script>
            var app = Elm.Main.init({
                flags: {
                    production: true,
                    firstDayOfWeek: JSON.parse(localStorage.getItem('firstDayOfWeek')),
                    defaultCreator: localStorage.getItem('defaultCreator'),
                    groupExpandAll: JSON.parse(localStorage.getItem('groupExpandAll'))
                }
            });
            app.ports.persistDefaultCreator.subscribe(function(name) {
                localStorage.setItem('defaultCreator', name);
            });
            app.ports.persistGroupExpandAll.subscribe(function(expanded) {
                localStorage.setItem('groupExpandAll', JSON.stringify(expanded));
            });
            app.ports.persistFirstDayOfWeek.subscribe(function(firstDayOfWeek) {
                localStorage.setItem('firstDayOfWeek', JSON.stringify(firstDayOfWeek));
            });
        </script>
    </body>
</html>

```

### Verify we can communicate with the alert manager from inside the cluster 
Here we verify that a POD from inside the cluster  can communicate to the alert manager as it would do prometheus by targeting port 9093.

```
$ kubectl run curl --image=radial/busyboxplus:curl -i --tty

If you don't see a command prompt, try pressing enter.
[ root@curl:/ ]$
[ root@curl:/ ]$
[ root@curl:/ ]$ nslookup alertmanager
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      alertmanager
Address 1: 10.104.237.146 alertmanager.monitoring.svc.cluster.local
[ root@curl:/ ]$ curl http://alertmanager.monitoring.svc.cluster.local:9093
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
        <link rel="icon" type="image/x-icon" href="favicon.ico" />
        <title>Alertmanager</title>
    </head>
    <body>
        <script>
            // If there is no trailing slash at the end of the path in the url,
            // add one. This ensures assets like script.js are loaded properly
            if (location.pathname.substr(-1) != '/') {
                location.pathname = location.pathname + '/';
                console.log('added slash');
            }
        </script>
        <script src="script.js"></script>
        <script>
            var app = Elm.Main.init({
                flags: {
                    production: true,
                    firstDayOfWeek: JSON.parse(localStorage.getItem('firstDayOfWeek')),
                    defaultCreator: localStorage.getItem('defaultCreator'),
                    groupExpandAll: JSON.parse(localStorage.getItem('groupExpandAll'))
                }
            });
            app.ports.persistDefaultCreator.subscribe(function(name) {
                localStorage.setItem('defaultCreator', name);
            });
            app.ports.persistGroupExpandAll.subscribe(function(expanded) {
                localStorage.setItem('groupExpandAll', JSON.stringify(expanded));
            });
            app.ports.persistFirstDayOfWeek.subscribe(function(firstDayOfWeek) {
                localStorage.setItem('firstDayOfWeek', JSON.stringify(firstDayOfWeek));
            });
        </script>
    </body>
</html>
```

Reload the Prometheus configuration  
Now If we open the Prometheus dashboard under "Status->Runtime & Build Information" we see our configured alert manager is in the list of the AlertManagers.
![AlertManager](../../doc/AlertManager-01.JPG)



### Alert Manager Ingress

We also would like to access the Alert Manager dashboard using e web browser. To do so as we did for prometheus and grafana, we deploy an ingress.  

***ingress.yaml***
```
---
kind: Service
apiVersion: v1
metadata:
  name: alertmanager-service-ingress
  namespace: monitoring
spec:
  selector:
    app: alertmanager
  ports:
  - protocol: TCP
    port: 9093
    targetPort: 9093
    name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alertmanager-ui
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: alertmanager.singleton.net
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: "alertmanager-service-ingress"
            port:
              number: 9093
```

We also need to add an entry to the /etc/hosts: 
***/etc/hosts***
```
#
192.168.56.10  prometheus.singleton.net
192.168.56.10  grafana.singleton.net
192.168.56.10  alertmanager.singleton.net

```

### Verification 
```
$ kubecetl apply -f ingress.yaml
service/alertmanager-service-ingress created
ingress.networking.k8s.io/alertmanager-ui created


$ kubectl get services
NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
alertmanager                   NodePort    10.97.151.227   <none>        9093:31000/TCP   9m2s
alertmanager-service-ingress   ClusterIP   10.104.102.73   <none>        9093/TCP         6s
grafana-service-ingress        ClusterIP   10.98.234.202   <none>        3000/TCP         6d
node-exporter                  ClusterIP   10.96.186.220   <none>        9100/TCP         11d
prometheus-service             NodePort    10.103.162.88   <none>        8080:30909/TCP   12d
prometheus-service-ingress     ClusterIP   10.110.95.79    <none>        9090/TCP         88d

$ k get ingress
NAME              CLASS   HOSTS                        ADDRESS         PORTS   AGE
alertmanager-ui   nginx   alertmanager.singleton.net   192.168.56.10   80      45s
grafana-ui        nginx   grafana.singleton.net        192.168.56.10   80      6d
prumetheus-ui     nginx   prometheus.singleton.net     192.168.56.10   80      88d

```
### Alert Manager UI
By accessing the configure ingress url ***alertmanager.singleton.net*** we access the dashboard 
![AlertManager](../../doc/AlertManager-02.JPG)


## Hight Availabilty and Alert Manager

We can setup multiple alert manager instances creating a cluster. These instances works with one another to de-duplicate and groups alerts.  
Prometheus should be aware of each alert manager instances. This is done by adding them the the prometheus configuration.
Each Alert Manager can be installed in different namespaces and configure  with --cluster.peer parameter pointing to the other alertmanagers PDD
Example :
```
# On alert manager in default namespace
    - --cluster.peer=alertmanager.monitoring.svc.cluster.local:9094

# On alert manager in monitoring namespace
    - --cluster.peer=alertmanager.default.svc.cluster.local:9093
```


## Alerting Rules
Are a way to define conditions and contet of Prometheus alerts. With alerting rules we define expressions conditions that will trigger en alert based on metrics data state.
Alerting rules are configured in the same way as recording rules. 
  
In Prometheus configuration file **prometheus.yaml** the location of the alerting rules files is defined in the **rule_files** oas we have seen for the recording rules.
There a **prometheus.rules** file is define with a rule rule alredy defined for an alert. All this can be seen inside the Prometheus config map.

Example
```
  prometheus.rules: |-
    groups:
    - name: custom_rules
      rules:
      - record: node_memory_MemFree_percent
        expr: 100 - (100 * node_memory_MemFree_bytes / node_memory_MemTotal_bytes)
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
          - "alertmanager.monitoring.svc.cluster.local :9093"
```

Basicaly the defined alert says that if the sum of the memory usage of the running containers is greater the 1 then an alert is fired.  
We can se this in the Prometheus dashboard under the Alert page:
![AlertManager](../../doc/AlertManager-03.JPG)

## Define our Own Alert
Using the previous example application [Example1v1](../021-Observability/Example1v1/README.md) we define here an alert that is fired when the number of exception in the application is greater that 20.  
To do so we need to change prometheus configuration map to add the scrap_configs to target the aplication and we need also to define the alert as defined in the following prometheus configuration map.
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
    - name: custom_rules
      rules:
      - record: node_memory_MemFree_percent
        expr: 100 - (100 * node_memory_MemFree_bytes / node_memory_MemTotal_bytes)
    - name: devopscube demo alert
      rules:
      - alert: High Pod Memory
        expr: sum(container_memory_usage_bytes) > 1
        for: 1m
        labels:
          severity: slack
        annotations:
          summary: High Memory Usage
    - name: http-exceptions
      rules: 
      - alert: TooManyExceptions
        expr: hello_world_exceptions_total > 20
        labels: 
          severity: critical
        annotations:
          summary: Too many exceptions occurred
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
          - "alertmanager.monitoring.svc.cluster.local:9093"
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

      - job_name: docker-exporter
        static_configs:
           - targets: ['192.168.56.200:9323']

      - job_name: 'cAdvisor'
        static_configs:
        - targets: ['192.168.56.200:8080']

      - job_name: 'kube-state-metrics'
        static_configs:
          - targets: ['kube-state-metrics.kube-system.svc.cluster.local:8080']

      - job_name: 'kube-state-telemetrics'
        static_configs:
          - targets: ['kube-state-metrics.kube-system.svc.cluster.local:8081']

      - job_name: 'example-001v1'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
          action: keep
          regex: example-001v1
        - source_labels: [__meta_kubernetes_pod_container_port_name]
          action: keep
          regex: metrics

```
As usuall to pick up the new config we need to restart prometheus. And if we open the prometheus dashboard on the alert page we will see that the **TooManyExceptions** is present.
![AlertManager](../../doc/AlertManager-04.JPG)

### Testing the alert
To verify the alert get fire as we previously did for [Example1v1](../021-Observability/Example1v1/README.md) we query via **curl** the POD running the example for a time enought to have the application randonly raise the 20 exceptions we need.

```
$ kubectl get pods -o wide
NAME                                     READY   STATUS    RESTARTS        AGE     IP            NODE         NOMINATED NODE   READINESS GATES
curl                                     1/1     Running   1 (21m ago)     21m     10.10.1.62    k8s-node1    <none>           <none>
example-001v1-9c47bd5b9-82zkz            1/1     Running   0               36m     10.10.1.57    k8s-node1    <none>           <none>
...


$ kubectl exec curl -it -- /bin/sh
[ root@curl:/ ]$
[ root@curl:/ ]$ while true
> do
> curl http://10.10.1.57:8001/hello
> done
Hello WorldHello WorldHello WorldHello .. ...
```

At some point the number of raised exceptions reache the imposed treshold of 20 and the alert is fired, and we can see this on the prometheus dashboard.
![AlertManager](../../doc/AlertManager-05.JPG)

If we open now the Alert Manger Dashboard we can see the prometheus as correctly sent the alert to the alert manager aswell
![AlertManager](../../doc/AlertManager-06.JPG)

## Managing Alerts
Alert manager allow more soffisticated management around alerts fired bu prometheus.
* **Routing**
Alert Manager implement a ***routing tree*** which is represented in the route block of the alert manager config file.  
The routing tree control how and when alerts will be sent.
* **Grouping** 
Allow to combine multiple related alerts into a single notification. ( **group_by** )
* **Inhibition** 
Allow to suppress an alert if another alert is already firing.  ( **inhibit_rule** )
* **Silences** 
Is a way to temporarely turn off certain notifications.
