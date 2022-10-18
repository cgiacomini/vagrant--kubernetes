#! /bin/bash

###############################################################################
log()
{
   echo "********************************************************************************"
   echo [`date`] - $1
   echo "********************************************************************************"
}

###############################################################################
systemUpdate()
{
   log "Inatall required packages"
   dnf install -y yum-utils net-tools curl
   dnf install -y iproute-tc
   systemctl enable firewalld
   systemctl start firewalld
}

###############################################################################
systemSettings()
{
   log "Setup sshd"
   cat /vagrant/hosts >> /etc/hosts
   systemctl stop sshd
   sed -i 's|#   PasswordAuthentication|PasswordAutentication|g' /etc/ssh/ssh_config
   sed -i 's|#   IdentityFile|IdentityFile|g' /etc/ssh/ssh_config
   sed -i 's|#   Port|Port|g' /etc/ssh/ssh_config
   systemctl start sshd

   log "Disabling swap permanently"
   swapoff -a
   sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
   free -h

   log "Disable SELINUX permanently."
   # Disable Selinux, as this is required to allow containers to access the
   # host filesystem, which is needed by pod networks and other services.
   setenforce 0
   sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

   log "Configure the firewall rules on the ports"
   # Allow VRRP traffic to pass between the keepalived nodes
   firewall-cmd --permanent --add-rich-rule='rule protocol value="vrrp" accept'
   # Required ports on Masters
   firewall-cmd --permanent --add-port=6443/tcp
   firewall-cmd --permanent --add-port=2379-2380/tcp
   firewall-cmd --permanent --add-port=10250-10252/tcp
   firewall-cmd --permanent --add-port=10257/tcp
   firewall-cmd --permanent --add-port=10259/tcp

   # Required ports on Workers
   firewall-cmd --permanent --add-port=30000-32767/tcp

   # Required ports for Flannel CNI
   firewall-cmd --permanent --add-port=8285/udp
   firewall-cmd --permanent --add-port=8472/udp

   firewall-cmd --add-masquerade --permanent
   firewall-cmd --reload
   firewall-cmd --list-ports

   log "Enable transparent masquerading and facilitate Virtual Extensible LAN (VxLAN) traffic for communication between Kubernetes pods across the cluster"
   tee /etc/modules-load.d/k8s.conf<<EOF
overlay
br_netfilter
EOF
 modprobe br_netfilter
 lsmod | grep br_netfilter
 lsmod | grep overlay

  log "Set bridged packets to traverse iptables rules."
tee /etc/sysctl.d/k8s.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
  sysctl --system
}

###############################################################################
installDocker()
{
  log "Removing podman (default now on centos)"
  dnf remove podman -y
  dnf remove buildah -y
  dnf remove containers-common -y
  dnf remove containernetworking-plugins  -y

  log "Installing docker-ce"
  dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
  yum install docker-ce -y

  log "Creating centos user."
  useradd -p $(openssl passwd -1 centos) -s /bin/bash centos
  
  log "Adding centos user as part o docker and sudo groups"
  usermod -aG docker centos
  usermod -aG wheel  centos
  mkdir /home/centos/.ssh
  cp /vagrant/id_rsa.pub /home/centos/.ssh/authorized_keys
  chmod 700 /home/centos/.ssh/authorized_keys
  chown -R centos.centos /home/centos/.ssh

  log "Apply recomanded kubernetes configuration"
  mkdir /etc/docker
  tee /etc/docker/daemon.json<<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
     "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
EOF

  log "Enable Docker."
  systemctl enable docker
  systemctl daemon-reload
  systemctl restart docker
  systemctl status docker

  log "Verify docker HelloWorld"
  docker run hello-world
}

###############################################################################
installKubernetes()
{
  log "Add Kubernetes repository"
tee /etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

  log "Install Kubernetes"
  dnf upgrade -y
  dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
  systemctl enable kubelet
  #systemctl start kubelet will not start until configured with kubeadm init
}

###############################################################################
systemUpdate
systemSettings
installDocker
installKubernetes
