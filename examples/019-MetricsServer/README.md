# Metrics Server Setup
## Deployement
```
$ curl -L --insecure https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml -o metrics-server.yaml
$ kubectl apply -f metrics-server.yaml
serviceaccount/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
service/metrics-server created
deployment.apps/metrics-server created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created
```
##  serverTLSBootstrap: true
On each cluster node we need to add ***serverTLSBootstrap***  in the kublet configuration file
```
$ sudo vi /var/lib/kubelet/config.yaml
...
...
imageMinimumGCAge: 0s
kind: KubeletConfiguration
logging:
  flushFrequency: 0
  options:
    json:
      infoBufferSize: "0"
  verbosity: 0
serverTLSBootstrap: true
memorySwap: {}
...
...

$ sudo systemctl restart kubelet
```
At this point the metrics server still complain with the followin error
```
# kubectl logs -n kube-system metrics-server-68fbbb47dc-g4cqz
E0208 09:07:24.559153       1 scraper.go:140] "Failed to scrape node" err="Get \"https://10.0.2.15:10250/metrics/resource\": x509: cannot validate certificate for 10.0.2.15 because it doesn't contain any IP SANs" node="kube-master01"
```
## List certificate requests
```
$ kubectl get csr
NAME        AGE     SIGNERNAME                      REQUESTOR                REQUESTEDDURATION   CONDITION
csr-2l6gr   78m     kubernetes.io/kubelet-serving   system:node:k8s-node1    <none>              Pending
csr-4lkv5   94s     kubernetes.io/kubelet-serving   system:node:k8s-node2    <none>              Pending
csr-8r5mp   34m     kubernetes.io/kubelet-serving   system:node:k8s-master   <none>              Pending
csr-d7n6p   33m     kubernetes.io/kubelet-serving   system:node:k8s-node1    <none>              Pending
csr-fc48r   18m     kubernetes.io/kubelet-serving   system:node:k8s-node1    <none>              Pending
csr-gtgxb   77m     kubernetes.io/kubelet-serving   system:node:k8s-node2    <none>              Pending
csr-h2556   50m     kubernetes.io/kubelet-serving   system:node:k8s-master   <none>              Pending
csr-hdkmm   48m     kubernetes.io/kubelet-serving   system:node:k8s-node1    <none>              Pending
csr-j2zjm   65m     kubernetes.io/kubelet-serving   system:node:k8s-master   <none>              Pending
csr-jf8h4   47m     kubernetes.io/kubelet-serving   system:node:k8s-node2    <none>              Pending
csr-klshb   63m     kubernetes.io/kubelet-serving   system:node:k8s-node1    <none>              Pending
csr-ll528   4m4s    kubernetes.io/kubelet-serving   system:node:k8s-master   <none>              Pending
csr-mt2bt   19m     kubernetes.io/kubelet-serving   system:node:k8s-master   <none>              Pending
csr-mtvc7   79m     kubernetes.io/kubelet-serving   system:node:k8s-node1    <none>              Pending
csr-ntlzn   79m     kubernetes.io/kubelet-serving   system:node:k8s-node1    <none>              Pending
csr-nvz85   62m     kubernetes.io/kubelet-serving   system:node:k8s-node2    <none>              Pending
csr-nzqj6   80m     kubernetes.io/kubelet-serving   system:node:k8s-master   <none>              Pending
csr-pngzj   77m     kubernetes.io/kubelet-serving   system:node:k8s-node2    <none>              Pending
csr-rmszz   32m     kubernetes.io/kubelet-serving   system:node:k8s-node2    <none>              Pending
csr-sm7rw   17m     kubernetes.io/kubelet-serving   system:node:k8s-node2    <none>              Pending
csr-tks7x   2m52s   kubernetes.io/kubelet-serving   system:node:k8s-node1    <none>              Pending
```
Approve all certifcates
```
$ kubectl get csr | grep Pending | awk '{print $1}' | while read i; do kubectl certificate approve $i; done
certificatesigningrequest.certificates.k8s.io/csr-2l6gr approved
certificatesigningrequest.certificates.k8s.io/csr-4lkv5 approved
certificatesigningrequest.certificates.k8s.io/csr-8r5mp approved
certificatesigningrequest.certificates.k8s.io/csr-d7n6p approved
certificatesigningrequest.certificates.k8s.io/csr-fc48r approved
certificatesigningrequest.certificates.k8s.io/csr-gtgxb approved
certificatesigningrequest.certificates.k8s.io/csr-h2556 approved
certificatesigningrequest.certificates.k8s.io/csr-hdkmm approved
certificatesigningrequest.certificates.k8s.io/csr-j2zjm approved
certificatesigningrequest.certificates.k8s.io/csr-jf8h4 approved
certificatesigningrequest.certificates.k8s.io/csr-klshb approved
certificatesigningrequest.certificates.k8s.io/csr-ll528 approved
certificatesigningrequest.certificates.k8s.io/csr-mt2bt approved
certificatesigningrequest.certificates.k8s.io/csr-mtvc7 approved
certificatesigningrequest.certificates.k8s.io/csr-ntlzn approved
certificatesigningrequest.certificates.k8s.io/csr-nvz85 approved
certificatesigningrequest.certificates.k8s.io/csr-nzqj6 approved
certificatesigningrequest.certificates.k8s.io/csr-pngzj approved
certificatesigningrequest.certificates.k8s.io/csr-rmszz approved
certificatesigningrequest.certificates.k8s.io/csr-sm7rw approved
certificatesigningrequest.certificates.k8s.io/csr-tks7x approved
```
## Verify metrics pod 
```
[centos@k8s-master ~]$ kubectl get pods -A
NAMESPACE              NAME                                         READY   STATUS    RESTARTS       AGE
ingress-nginx          ingress-nginx-controller-d5955bbfd-vhj7w     1/1     Running   13 (31h ago)   22d
kube-flannel           kube-flannel-ds-2cws4                        1/1     Running   58 (31h ago)   51d
kube-flannel           kube-flannel-ds-8sgkd                        1/1     Running   43 (31h ago)   51d
kube-flannel           kube-flannel-ds-mdthm                        1/1     Running   40 (31h ago)   51d
kube-system            coredns-565d847f94-c5q56                     1/1     Running   15 (31h ago)   23d
kube-system            coredns-565d847f94-cjv8l                     1/1     Running   15 (31h ago)   23d
kube-system            etcd-k8s-master                              1/1     Running   57 (31h ago)   51d
kube-system            kube-apiserver-k8s-master                    1/1     Running   57 (31h ago)   51d
kube-system            kube-controller-manager-k8s-master           1/1     Running   57 (31h ago)   51d
kube-system            kube-proxy-6rxt4                             1/1     Running   44 (31h ago)   51d
kube-system            kube-proxy-kr58n                             1/1     Running   56 (31h ago)   51d
kube-system            kube-proxy-l7fsm                             1/1     Running   40 (31h ago)   51d
kube-system            kube-scheduler-k8s-master                    1/1     Running   57 (31h ago)   51d
kube-system            metrics-server-8ff8f88c6-msppc               1/1     Running   0              18m
kubernetes-dashboard   dashboard-metrics-scraper-586df688bf-h54nn   1/1     Running   12 (31h ago)   22d
kubernetes-dashboard   kubernetes-dashboard-54f784b599-7j47c        1/1     Running   12 (31h ago)   22d
```

The metrics pod is now READY and the metrics available
```
$ kubectl top nodes
NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
k8s-master   221m         11%    1332Mi          36%
k8s-node1    52m          2%     640Mi           17%
k8s-node2    54m          2%     605Mi           16%

$ kubectl top pods -A --sort-by=cpu
NAMESPACE              NAME                                         CPU(cores)   MEMORY(bytes)
kube-system            kube-apiserver-k8s-master                    61m          350Mi
kube-system            etcd-k8s-master                              35m          93Mi
kube-system            kube-controller-manager-k8s-master           18m          55Mi
kube-flannel           kube-flannel-ds-mdthm                        10m          34Mi
kube-flannel           kube-flannel-ds-8sgkd                        9m           31Mi
kube-flannel           kube-flannel-ds-2cws4                        5m           34Mi
kube-system            metrics-server-8ff8f88c6-msppc               4m           27Mi
kube-system            kube-scheduler-k8s-master                    4m           25Mi
kube-system            coredns-565d847f94-c5q56                     3m           21Mi
ingress-nginx          ingress-nginx-controller-d5955bbfd-vhj7w     3m           108Mi
kube-system            kube-proxy-kr58n                             2m           23Mi
kube-system            kube-proxy-6rxt4                             2m           23Mi
kube-system            coredns-565d847f94-cjv8l                     2m           20Mi
kube-system            kube-proxy-l7fsm                             1m           23Mi
kubernetes-dashboard   dashboard-metrics-scraper-586df688bf-h54nn   1m           19Mi
kubernetes-dashboard   kubernetes-dashboard-54f784b599-7j47c        1m           36Mi
```


