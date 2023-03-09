# Install NFS Server on CentOs8s

## Software installation

Install the following packages on the server and all clients node:

* 192.168.56.200 centos8s-server.singleton.net centos8s-server
* 192.168.86.10  k-master.garfield.net k-master
* 192.168.86.11  k-node1.garfield.net k-node1
* 192.168.86.12  k-node2.garfield.net k-node2


```
$ sudo yum -y install nfs-utils  libnfs-utils nfs4-acl-tools
```

On the server side (centos8s-server.singleton.net centos8s-server)

```
$ sudo systemctl start nfs-server.service
$ sudo systemctl enable nfs-server.service
$ sudo systemctl status nfs-server.service
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
   Active: active (exited) since Tue 2023-03-07 08:26:43 UTC; 1h 2min ago
 Main PID: 1438 (code=exited, status=0/SUCCESS)
    Tasks: 0 (limit: 23236)
   Memory: 0B
   CGroup: /system.slice/nfs-server.service

Mar 07 08:26:43 centos8s-server systemd[1]: Starting NFS server and services...
Mar 07 08:26:43 centos8s-server systemd[1]: Started NFS server and services.

```
## NFS Server configuration

The configuration files for the NFS server are:  

* /etc/nfs.conf      – configuration file for the NFS daemons.
* /etc/nfsmount.conf – NFS mount configuration file.

Create a directory we intend to share among the other nodes of the kubernetes cluster called cluster_nfs
```
$ sudo mkdir -p /mnt/nfs_shares/cluster_nfs
```

Export the above filesystem by adding the following line in the ***/etc/exports*** file:
```
/mnt/nfs_shares/cluster_nfs  	192.168.56.0/24(rw,sync)
```
* ***rw*** :  Allow both read and write requests on this NFS volume.
* ***sync*** : Reply to requests only after the changes have been committed to stable storage 

***Note:*** see maan exports for more options


## Export thefile system
run the exportfs command
```
$ sudo  exportfs -arv
exporting 192.168.56.0/24:/mnt/nfs_shares/cluster_nfs

```
 * **-a** flag:  means export or unexport all directories, 
 * **-r** flag:  means reexport all directories, synchronizing **/var/lib/nfs/etab** with /etc/exports and files under **/etc/exports.d**
 * **-v** flag:  enables verbose output.

Check export nfs
```
$ sudo exportfs  -s
/mnt/nfs_shares/cluster_nfs  192.168.56.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

```

## Firewalld
if firewalld is activated then we need to allow traffic 

```
$ sudo firewall-cmd --permanent --add-service=nfs
success
$ sudo firewall-cmd --permanent --add-service=rpc-bind
success
$ sudo firewall-cmd --permanent --add-service=mountd
success
$ sudo firewall-cmd --reload
success

```

## Client configuration
On the clients host we can now verify the server's exported filesystems
```
$ showmount -e 192.168.56.200
Export list for 192.168.56.200:
/mnt/nfs_shares/cluster_nfs 192.168.56.0/24
```
### Create the mount point on all client nodes and mount the nfs
```
$ sudo mkdir -p /mnt/cluster_nfs
$ sudo mount -t nfs 192.168.56.200:/mnt/nfs_shares/cluster_nfs /mnt/cluster_nfs
```

# AutoFS
We could permanently mount the shared foulder on all nodes by modifiyng the **/etc/fstab** file but there is a better choice by using AutoFs.
Autofs is a program that automatically mounts specified directories on an on-demand basis. 
It is based on a kernel module for high efficiency, and can manage both local directories and network shares. 
These automatic mount points are mounted only when they are accessed, and unmounted after a certain period of inactivity. 
This on-demand behavior saves bandwidth and results in better performance than static mounts managed by /etc/fstab. 
While autofs is a control script, automount is the command (daemon) that does the actual auto-mounting.

## AutoFs Installation
Install autofs on all nodes of the cluster that need to mount the cluster_nfs shared directory.   

```
$ sudo yum install autofs
$ sudo systemctl enable --now autofs
$ sudo systemctl status autofs
```
## AutoFs Configuration
The master default configuration for AutoFs is **/etc/auto.master**. 
The key concept in AutoFs are ***maps***.  


## Creating an indirect mapping
Here we would like to configure AutoFs in such a way that on any cluster node we automatically mount the shared folder only when we access it.  
We need first to create a map file where we associate a key with the shared directory from the NFS server.  
The mount information for an NFS server are as follow:

```
$ sudo showmount  -e 192.168.56.200
Export list for 192.168.56.200:
/mnt/nfs_shares/cluster_nfs 192.168.56.0/24
```

Create a file called ***/etc/auto.cluster_nfs*** and add the following line:
```
cluster_nfs   -fstype=nfs  192.168.56.200:/mnt/nfs_shares/cluster_nfs

```
Note: that **cluster_nfs** is a convenient key that as the same name of the sared folder but be any string you like.
AutoFS will mount /mnt/nfs_shares/cluster_nfs when we try to access a directory with that name on the mount point.

Modify ***auto.master*** by adding the following line to the end of it.  

```
/mnt    /etc/auto.cluster_nfs
```
Restart AutoFs  
```
sudo systemctl restart autofs
```
Now if we access **/mnt** directoy we can see is still empty; the shared directory will be mounted only when we try to access **/mnt/<key>**

```
$ cd /mnt 
$ ls -la
.
..
$ cd /mnt/cluster_nfs
$ pwd 
/mnt/cluster_nfs
```

## Creating a direct mapping

The mount information for an NFS server are as follow:

```
$ sudo showmount  -e 192.168.56.200
Export list for 192.168.56.200:
/mnt/nfs_shares/cluster_nfs 192.168.56.0/24
```

Create a file called ***/etc/auto.cluster_nfs*** and add the following line:
```
/mnt/cluster_nfs   -fstype=nfs  192.168.56.200:/mnt/nfs_shares/cluster_nfs

```
Note: that **/mnt/cluster_nfs** ist the mount point directory that may or may not exists. if does not exists the directory mount point is craated.  
AutoFS will mount /mnt/nfs_shares/cluster_nfs at boot time. If for some reason the directory is not mounted it will be mounted when accessing it.

Modify ***auto.master*** by adding the following line to the end of it.
The direct mount is specified using the **/-** notetion.

```
/-    /etc/auto.cluster_nfs
```

Restart AutoFs
```
sudo systemctl restart autofs
```
Now if we access **/mnt** directoy we can see the content of the shared folder
