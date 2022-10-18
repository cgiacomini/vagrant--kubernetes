#! /bin/bash

###############################################################################
log()
{
   echo "***********************************************************************"
   echo [`date`] - $1
   echo "***********************************************************************"
}

###############################################################################

# Fix [ERROR CRI]: container runtime is not running:
sed -ie 's|^disabled_plugins|#disabled_plugins|g'  /etc/containerd/config.toml
systemctl restart containerd

# Join node to the Kubernetes cluster
log "`hostname -s` Join Cluser"
/bin/bash /vagrant/join-cluster.sh

log "`hostname -s` Setup Kubernetes config credentials"

mkdir -p $HOME/.kube
cp -i /vagrant/kube-config $HOME/.kube/config

mkdir -p ~vagrant/.kube
cp  /vagrant/kube-config ~vagrant/.kube/config
chown vagrant:vagrant ~vagrant/.kube/config

mkdir -p ~centos/.kube
cp /vagrant/kube-config ~centos/.kube/config
chown centos:centos ~centos/.kube/config
