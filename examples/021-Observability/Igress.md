# Method-2 
## Create an Ingress for Prometheus UI
***ingress.yaml***
```
---
kind: Service
apiVersion: v1
metadata:
  name: prometheus-service-ingress
  namespace: monitoring
  annotations:
     prometheus.io/scrape: 'true'
     prometheus.io/port:   '9090'
spec:
  selector:
    app: prometheus-server
  ports:
  - protocol: TCP
    port: 9090
    targetPort: 9090
    name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prumetheus-ui
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.singleton.net
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: "prometheus-service-ingress"
            port:
              number: 9090

```
The Ingress allow to access the Prometheus UI via the specified URL *http://prometheus.singleton.net*  
For this to work, as explained in example in [README.md](https://github.com/cgiacomini/vagrant--kubernetes#testing-nginx-ingress-controller) since we do not gave a load balancer we need to configure the
FQDN of the prometheus URL in the /etc/hosts giving to it the same IP address of the kubernetes master node where we run the nginx ingress controller.

***/etc/hosts***
```
#
...
192.168.56.10  prometheus.singleton.net
...
```