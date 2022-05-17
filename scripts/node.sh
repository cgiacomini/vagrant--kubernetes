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
sudo sed -ie 's|^disabled_plugins|#disabled_plugins|g'  /etc/containerd/config.toml
sudo systemctl restart containerd

# Join node to the Kubernetes cluster
log "`hostname -s` Join Cluser"
sudo /bin/bash /vagrant/join-cluster.sh

log "`hostname -s` Setup Kubernetes config credentials"
mkdir -p $HOME/.kube
sudo cp -i /vagrant/kube-config $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sudo mkdir -p ~vagrant/.kube
sudo cp  /vagrant/kube-config ~vagrant/.kube/config
sudo chown vagrant:vagrant ~vagrant/.kube/config

sudo mkdir -p ~centos/.kube
sudo cp /vagrant/kube-config ~centos/.kube/config
sudo chown centos:centos ~centos/.kube/config
