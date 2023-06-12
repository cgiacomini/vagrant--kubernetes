# Method-1 
## Create a NodePort service
To allow access to the prometheus metrics via the prometheus dashboard we need first to configure 
a service to access it. The simplest way to access it is via a NodePort services.

The following service expose port 8080 and target the prometheus-server port 9090,  
it also open a NodePort 30909 on all kubernetes nodes the forward traffic to port 8080.

***service.yaml***
```
apiVersion: v1
kind: Service
metadata:
    name: prometheus-service
    namespace: monitoring
    annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port:   '9090'
spec:
    selector:
        app: prometheus-server
    type: NodePort
    ports:
    - port: 8080
      targetPort: 9090 
      nodePort: 30909
```