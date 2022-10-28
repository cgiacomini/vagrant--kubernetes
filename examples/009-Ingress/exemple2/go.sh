kubectl create deployment mars   --image=nginx --dry-run=client -o yaml | tee mars-dc.yaml
kubectl create deployment saturn --image=httpd --dry-run=client -o yaml | tee saturn-dc.yaml

kubectl apply -f mars-dc.yaml
kubectl apply -f saturn-dc.yaml

kubectl expose deployment mars --port 80 --dry-run -o yaml | tee mars-svc.yaml
kubectl expose deployment saturn --port 80 --dry-run -o yaml | tee saturn-svc.yaml

kubectl apply -f mars-svc.yaml
kubectl apply -f saturn-svc.yaml

echo "make sure to add these two lines in /etc/hosts"
echo "192.168.56.10  mars.singleton.net"
echo "192.168.56.10  saturn.singleton.net"


# Create the ingress. Enything is sento mars.singleton.net is redirected to mars  the same for saturn.singleton.net is redirected to saturn
kubectl create ingress multihost --class='nginx' --rule="mars.singleton.net/=mars:80" --rule="saturn.singleton.net/=saturn:80" --dry-run=client -o yaml | tee multihost.yaml
kubectl apply -f multihost.yaml


curl mars.singleton.net
curl saturn.singleton.net
