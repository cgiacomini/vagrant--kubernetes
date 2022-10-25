# Private Registry using Securing communication

Right now we have one master node  (k8s-master) and two worker nodes (k8s-node1, k8s-node2).  
Here we add a 4th machine (centos8s-server), this new host is intended to run all additional services that are  
not properly related to kubernetes, for example a local private docker registry.  
For this reason the new host will not have kubernets software installe on it.


The new hostname is to be configured also in each kubernetes nodes in ***/etc/hosts*** since right now
we do not have a DNS runnig.

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
