#! /bin/bash

###############################################################################
# Master Node – This machine generally acts as the control plane and runs the
# cluster database and the API server (which kubectl CLI communicates with).

export MASTER_IP="192.168.56.10"
export NODENAME=$(hostname -s)
export POD_CIDR="10.10.0.0/16"

###############################################################################
log()
{
   echo "********************************************************************************"
   echo [`date`] - $1
   echo "********************************************************************************"
}

###############################################################################
initializeMaster()
{
   # Fix [ERROR CRI]: container runtime is not running:
   sed -ie 's|^disabled_plugins|#disabled_plugins|g'  /etc/containerd/config.toml
   systemctl restart containerd

   log "Configure kubeadm"
   kubeadm config images pull

   log "Master node initialization"
   kubeadm init --apiserver-advertise-address=$MASTER_IP \
                     --pod-network-cidr=$POD_CIDR 

   mkdir -p $HOME/.kube
   cp -f /etc/kubernetes/admin.conf $HOME/.kube/config

   mkdir -p ~centos/.kube
   cp -f /etc/kubernetes/admin.conf ~centos/.kube/config
   chown -R centos:centos ~centos/.kube

   mkdir -p ~vagrant/.kube
   cp -f /etc/kubernetes/admin.conf ~vagrant/.kube/config
   chown -R vagrant:vagrant ~vagrant/.kube

   log "Save kubeconfig"
   cp -f /etc/kubernetes/admin.conf /vagrant/kube-config
   chown vagrant:vagrant /vagrant/kube-config
   chmod u+x  /vagrant/kube-config

   log "Save join script"
   kubeadm token create --print-join-command > /vagrant/join-cluster.sh
   chmod u+x /vagrant/join-cluster.sh

   log "Verify Status"
   kubectl get nodes 
   kubectl get pods -o wide -A
}

###############################################################################
installFlannelCNI()
{
   log "Configure Flannel CNI"
   URL=https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml
   curl -OL --insecure $URL

   FLANNEL_DEFAULT_CIDR=10.244.0.0/16
   log "Adapt POD CIDR Network default: $FLANNEL_DEFAULT_CIDR -> $POD_CIDR"
   sed -i "s|${FLANNEL_DEFAULT_CIDR}|${POD_CIDR}|" kube-flannel.yml

   # Force flannel to use host only netework interface
   text="\ \ \ \ \ \ \ \ \- --iface=eth1"
   sed -i "/--kube-subnet-mgr/ a  ${text}"  kube-flannel.yml

   # Applly manifest
   kubectl apply -f  kube-flannel.yml

   # Verify status
   kubectl get pods -A
   
   # Restart CoreDns Pods
   kubectl delete pods -l  k8s-app=kube-dns  -n kube-system

   # Verify status
   kubectl get pods -A
   kubectl get nodes
}

###############################################################################
installNgnixIngressController()
{
   # Install nginx for baremetal ( Nodeport ) Virtualbox does not have loadbalancer
   GIT_API_URL=https://api.github.com/repos/kubernetes/ingress-nginx/releases/latest
   VERSION=`curl -s $GIT_API_URL | grep tag_name |  cut -d '"' -f 4`
   URL=http://raw.githubusercontent.com/kubernetes/ingress-nginx/${VERSION}/deploy/static/provider/baremetal/deploy.yaml

   curl -OL --insecure $URL
   kubectl apply -f deploy.yaml

   log "Force NGNIX Controller POD to run on the Master node."
   # add a label on the master node
   kubectl label node $NODENAME run-ingress-controller=true
   # Verify the node have the new label
   kubectl get node --show-labels | grep master
   # Patch nginx deployment
   cat <<EOF | tee /tmp/node-selector-patch.yaml
spec:
  template:
    spec:
      nodeSelector:
        run-ingress-controller: "true"
EOF
  log "Add tolerations property to ingress controller deployment"
  # master node has tain node-role.kubernetes.io/master and
  # node-role.kubernetes.io/control-plane. We need to make 
  # ingress controller POD telerate these taints in order to
  # be able to be deployed on the master node

  cat <<EOF | tee /tmp/ingress-pod-toleration-patch.yaml
spec:
  template:
    spec:
      tolerations:
        - key: node-role.kubernetes.io/master
          operator: Equal
          effect: NoSchedule
        - key: node-role.kubernetes.io/control-plane
          operator: Equal
          effect: NoSchedule
EOF

  log "Add ingress controller exernal IP"
  cat <<EOF | tee /tmp/external-ips.yaml
spec:
  externalIPs:
  - 192.168.56.10
EOF

kubectl -n ingress-nginx  patch  deployment/ingress-nginx-controller --patch "$(cat /tmp/node-selector-patch.yaml)"
kubectl -n ingress-nginx  patch  deployment/ingress-nginx-controller --patch "$(cat /tmp/ingress-pod-toleration-patch.yaml)"
kubectl -n ingress-nginx  patch  svc/ingress-nginx-controller        --patch "$(cat /tmp/external-ips.yaml)"

# Let some time to  pod to be up and running 
sleep  1m
POD_NAMESPACE=ingress-nginx
POD_NAME=$(kubectl get pods -n $POD_NAMESPACE -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[2].metadata.name}')
kubectl exec -it $POD_NAME -n $POD_NAMESPACE -- /nginx-ingress-controller --version
}


###############################################################################
installDashboard()
{
   GIT_API_URL=https://api.github.com/repos/kubernetes/dashboard/releases/latest
   VERSION=`curl -s $GIT_API_URL | grep tag_name |  cut -d '"' -f 4`

   log "Install Kubernetes Dashboard version : $VERSION"
   URL=https://raw.githubusercontent.com/kubernetes/dashboard/$VERSION/aio/deploy/recommended.yaml 
   curl -OL --insecure $URL
   kubectl apply -f recommended.yaml

   log "Force dashboard POD to run on the Master node."
   # add a label on the master node
   kubectl label node $NODENAME run-dashboard=true
   # Verify the node have the new label
   kubectl get node --show-labels | grep master
   # Patch dashboard deployment
   cat <<EOF | tee /tmp/node-selector-patch.yaml
spec:
  template:
    spec:
      nodeSelector:
        run-dashboard: "true"
EOF

  log "Add tolerations property to ingress controller deployment"
  # master node has tain node-role.kubernetes.io/master and
  # node-role.kubernetes.io/control-plane. We need to make 
  # dashboard controller POD telerate these taints in order to
  # be able to be deployed on the master node
  cat <<EOF | tee /tmp/dashboard-pod-toleration-patch.yaml
spec:
  template:
    spec:
      tolerations:
        - key: node-role.kubernetes.io/master
          operator: Equal
          effect: NoSchedule
        - key: node-role.kubernetes.io/control-plane
          operator: Equal
          effect: NoSchedule
EOF
  kubectl -n kubernetes-dashboard  patch  deployment/kubernetes-dashboard      --patch "$(cat /tmp/node-selector-patch.yaml)"
  kubectl -n kubernetes-dashboard  patch  deployment/kubernetes-dashboard      --patch "$(cat /tmp/dashboard-pod-toleration-patch.yaml)"
  kubectl -n kubernetes-dashboard  patch  deployment/dashboard-metrics-scraper --patch "$(cat /tmp/node-selector-patch.yaml)"
  kubectl -n kubernetes-dashboard  patch  deployment/dashboard-metrics-scraper --patch "$(cat /tmp/dashboard-pod-toleration-patch.yaml)"
 

  kubectl -n kubernetes-dashboard  get service kubernetes-dashboard -o yaml > /vagrant/kubernetes-dashboard-np.yaml
  sed -i 's|targetPort: 8443|targetPort: 8443\n    nodePort: 30002|' /vagrant/kubernetes-dashboard-np.yaml
  sed -i 's|type: ClusterIP|type: NodePort|'                         /vagrant/kubernetes-dashboard-np.yaml
  kubectl -n kubernetes-dashboard  delete service kubernetes-dashboard
  cat /vagrant/kubernetes-dashboard-np.yaml  | kubectl apply -f -

   log "Create Dashboard User"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-secret
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF

# Wait for the token controller to populate the secret with a token:
while ! kubectl describe secret admin-user-secret -n kubernetes-dashboard | grep -E '^token' >/dev/null; do
  echo "waiting for token..." >&2
  sleep 1
done

}

###############################################################################
echo "WHO AM I : " $(whoami)
initializeMaster
installFlannelCNI
installNgnixIngressController
installDashboard
