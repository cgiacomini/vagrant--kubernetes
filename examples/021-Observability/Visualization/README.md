# Visualization
Visualization consist to create visual representations of our Prometheus data.
Basically to have a on place where can visualize Prometheus data in form of graphs and chards etc.
For this purpose there are a variety of tools available, some alredy built in the prometheus dashboard and other provided by external projects such

* **Expression browsers** : available on prometheus dashboard under the Graph endpoint.
* **Console Templates** : allow to create visualization consoles using go templating language
* **Grafana**

## Console Templates
Console templates are served by Prometheus server and are essentially a simple way to create a page that is served by the Prometheus server and that displays your data in a customized format.  
To use console templates we have to make sure how prometheus server is started with the **--web.console.templates** and **--web.console.libraries** options pointing to the directory containing the console templestes we want to use.  
The deployed prometheus POD does not have yet specified in the list of prometheus arguments, but the POD image already come with a set examples of consoles and the relate console libreries respectively inside **/usr/share/prometheus/consoles** and **/usr/share/prometheus/console_libraries**. 


Template console use go language templates and html. Examples are in /usr/share/prometheus/consoles of our deployed prometheus POD.

### Change Prometheus deploment config
In our prometheus deployment.yaml file we have to add the following arguments for the container image:

```
apiVersion: apps/v1$
kind: Deployment$
metadata:$
  name: prometheus-deployment$
  namespace: monitoring$
  labels:$
    app: prometheus-server$
spec:$
  replicas: 1$
  selector:$
    matchLabels:$
      app: prometheus-server$
  template:$
    metadata:$
      labels:$
        app: prometheus-server$
    spec:$
      serviceAccountName: prometheus$
      containers:$
        - name: prometheus$
          image: prom/prometheus$
          args:$
            - "--storage.tsdb.retention.time=12h"$
            - "--config.file=/etc/prometheus/prometheus.yml"$
            - "--storage.tsdb.path=/prometheus/"$
            - "--web.console.libraries=/usr/share/prometheus/console_libraries"$
            - "--web.console.templates=/usr/share/prometheus/consoles"$
          ports:$
            - containerPort: 9090$
          resources:$
            requests:$
              cpu: 500m$
              memory: 500M$
            limits:$
              cpu: 1$
              memory: 2Gi$
          volumeMounts:$
            - name: prometheus-config-volume$
              mountPath: /etc/prometheus/$
            - name: prometheus-storage-volume$
              mountPath: /prometheus/$
      volumes:$
        - name: prometheus-config-volume$
          configMap:$
            defaultMode: 420$
            name: prometheus-server-conf$
        - name: prometheus-storage-volume$
          persistentVolumeClaim:$
            claimName: prometheus-pvc$
```

Now we can have a look of the customazed way to visualize the metrics data for example by loading this URL in a browser:
```
http://prometheus.singleton.net/consoles/prometheus-overview.html
```
Result:  
![Template Console Example](../../../doc/TemplateConsoles-01.JPG)

