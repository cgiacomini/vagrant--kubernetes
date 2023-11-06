# ArgoCD Installation
Here we are going to install ArgoCD on a 3 nodes kubernetes cluster. We deploy it using the installation notes described in https://kubebyexample.com/learning-paths/argo-cd/argo-cd-getting-started.  
After the installation is completed we modify the ArgoCD server deployment and service to make it running on the k8s-master node and make it accessible via an ingress.
```
# Create a dedicated namespace for ArgoCD
$ kubectl create namespace argocd
namespace/argocd created

# Apply the YAML file fron the Argo Project's git repo.
$ kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Download the ArgoCD CLI for the OS from where you normally operate on the kubernetes cluster. I am normally using cygwin so I download a windows version of the ArgoCD CLI.
# Fpr windows
$ curl -OL https://github.com/argoproj/argo-cd/releases/download/v2.9.0/argocd-windows-amd64.exe
# For linux
# $ curl -OL https://github.com/argoproj/argo-cd/releases/download/v2.9.0/argocd-linux-arm64
...

# Move the executable in a directory pointed by $PATH
$ mov argocd-windows-amd64.exe /usr/local/bin/argocd
```

After installatio  we should have all PODs up and running in the *argocd* namespace.
```
# Change current config context to point to argocd namespace
$ kubectl config set-context --current --namespace=argocd
Context "kubernetes-admin@kubernetes" modified.

# Verify PODs
$ kubectl get pods
NAME                                                READY   STATUS    RESTARTS      AGE
argocd-application-controller-0                     1/1     Running   0             12m
argocd-applicationset-controller-56899cff6c-n6jz4   1/1     Running   0             12m
argocd-dex-server-6878c56b95-9j6dd                  1/1     Running   0             12m
argocd-notifications-controller-69c96f9cf8-z5kjz    1/1     Running   0             12m
argocd-redis-685866888c-g56pb                       1/1     Running   0             12m
argocd-repo-server-58bc4fddb4-hfspc                 1/1     Running   0             12m
argocd-server-5cc766df8c-dwhjt                      1/1     Running   0             12m

# Verify argocd CLI
$ argocd version --client
argocd: v2.9.0+9cf0c69
  BuildDate: 2023-11-06T05:01:52Z
  GitCommit: 9cf0c69bbe70393db40e5755e34715f30179ee09
  GitTreeState: clean
  GoVersion: go1.21.3
  Compiler: gc
  Platform: linux/amd64
```

## Make ArgoCD Ingress Configuration
First we need to change the argocd-server service from NodePort Type to ClusterIP.
[ArgoCD server Service](./playbooks/argocd-server-service.yaml)

We also need to change the deployment to add ***tolerations*** to the master node ***taint***, the **nodeSelector** to force deployment on the node labeled ***run-argocd: "true"*** and also we need to add ***"--insecure"*** option to the container arguments.  
To configure argocd server to handle TLS see the proper section in  https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/

[ArgoCD server Deployment](./playbooks/argocd-server-deployment.yaml)

Here is the ingress that allow to acces ArgoCD server UI on HTTP port 80 using the FQDN ***argocd.singleton.net***.
[ArgoCD Ingress](./playbook/argocd-ingress.yaml)

Note that we do not have dns server and loadblancer so we need to add the following line in the host */etc/hosts* file.
```
192.168.56.10 k8s-master.singleton.net k8s-master argocd.singleton.net
```

## Verification
ArgoCD also comes with an already built-in admin user and password.  
The password is randomly generated and stored in the **argocd-initial-admin-secret** secret, to retrieve it we can use the following command:

```
$ kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
tiJw1x9MMjsF7VTP
```

We can try to login with argocd CLI
```
# Login into argocd server
$ argocd login --grpc-web  --insecure --username=admin --password=tiJw1x9MMjsF7VTP argocd.singleton.net
'admin:login' logged in successfully
Context 'argocd.singleton.net' updated

# List the kubernetes configured clusters
```
$ argocd  cluster list
SERVER                          NAME        VERSION  STATUS   MESSAGE                                                  PROJECT
https://kubernetes.default.svc  in-cluster           Unknown  Cluster has no applications and is not being monitored.
```

we can also access the Web UI using http://argocd.singleton.net URL and the same credentials used with argocd CLI.

