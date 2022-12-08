# Private Registry using Securing communication

Right now we have one master node  (k8s-master) and two worker nodes (k8s-node1, k8s-node2).  
Here we add a 4th machine (centos8s-server).   
This new host will not have kubernets software installed on it.  
It is only intended to run all additional services,for example a local private docker registry.   
The new hostname FQDN is added to each kubernetes nodes ***/etc/hosts***, since right now we do not have a DNS service runnig.

***new /etc/hosts for all nodes***
```
192.168.56.10  k8s-master.singleton.net k8s-master
192.168.56.11  k8s-node1.singleton.net k8s-node1
192.168.56.12  k8s-node2.singleton.net k8s-node2

192.168.56.200 centos8s-server.singleton.net centos8s-server
```

- [Insecure Docker Registry](InsecureRegistry.md)  
- [Basic Authentication Registry](BasicAuthenticationRegistry.md)  
- [Self Signed CA Certificate Registry](SelfSignedCACertificateRegistry.md)
