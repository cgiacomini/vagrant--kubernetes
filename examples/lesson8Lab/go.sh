1.

$ kubectl create deployment nginx --image nginx --replicas=2 -n training --dry-run=client -o yaml | tee nginx-dc.yaml
$ kubectl create service clusterip  nginx --tcp=80:80 --dry-run=client -o yaml | tee nginx-clusterip-sv.yaml
$ kubectl run curl  --image=radial/busyboxplus:curl -i --tty
".If you don't see a command prompt, try pressing enter.
[ root@curl:/ ]$ curl http://10.10.1.94
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
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
[ root@curl:/ ]"


2. kubectl create service nodeport  nginxnp  --tcp=80:80  --node-port=32000 --dry-run=client -o yaml | kubectl set selector --local -f - app=nginx -o yaml  | tee nginx-nodeport-sv.yaml
kubectl apply -f nginx-nodeport-sv.yaml

# get node ip on which is running one of the pods
kubectl get pods -o wide
kubectl get nodes

# then get the info via curl
$ curl http://192.168.56.11:32000
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
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

