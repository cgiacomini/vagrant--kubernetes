# ConfigMap

## ConfigMap for setting Environment variables
We can create configMaps for environment variable settings that will be used later by PODs 
in their containers environment. We can use a file containing the variable settings or
simply use the litteral aproach.

### Create ConfigMap from a file containing variable setting.

```
# Create file containing variables
echo "CAR=TOYOTA" > variables-file

# Create the configmap
$ kubectl create cm variables --from-env-file=variables-file
configmap/variables created

# Check configmap has been created
$ kubectl get cm
NAME               DATA   AGE
variables          1      8s

# Check configmap content
$ kubectl get cm variables -o yaml
apiVersion: v1
data:
  CAR: TOYOTA
kind: ConfigMap
metadata:
  creationTimestamp: "2022-01-17T16:13:25Z"
  name: variables
  namespace: default
  resourceVersion: "286352"
  uid: c53ff17a-0f9b-4599-ab53-13fd1a92623a

```

### Create ConfigMap from literals

```
# Create the configmap
kubectl create cm literals --from-literal=CAR=FIAT --from-literal=TRUCK=JUMPER
configmap/literals created

# Check configmap has been created
$ kubectl get cm
NAME               DATA   AGE
literals           2      5s

# Check configmap content
$ kubectl get cm literals -o yaml
apiVersion: v1
data:
  CAR: FIAT
  TRUCK: JUMPER
kind: ConfigMap
metadata:
  creationTimestamp: "2022-01-17T16:17:17Z"
  name: literals
  namespace: default
  resourceVersion: "286705"
  uid: 603934c3-ca9f-4df0-ba0a-427b845e5487
```

### Example using configMap in a POD
***001-pod.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
spec:
  containers:
  - name: demo-pod
    image: cirros
    command: ["/bin/sh", "-c", "watch -n 5 env"]
    envFrom:
        - configMapRef:
            name: variables
```
# Deployment
```
$ kubectl apply -f 001-pod.yaml
pod/demo-pod created

$ kubectl get pods
NAME       READY   STATUS    RESTARTS   AGE
demo-pod   1/1     Running   0          5s

$ kubectl logs demo-pod

Every 5s: env                                               2022-01-18 10:07:13

KUBERNETES_SERVICE_PORT=443
KUBERNETES_PORT=tcp://10.96.0.1:443
HOSTNAME=demo-pod
SHLVL=2
HOME=/root
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_PROTO=tcp
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
KUBERNETES_SERVICE_HOST=10.96.0.1
PWD=/
CAR=TOYOTA
```

## ConfigMap for configfiles
We can create configmaps to provide configuration files; the PODs will use them as a mounted volume which contains the cofiguration file.


The following yaml file define a configMap named **cm-example**. 
This configMap define  configuration file the contains a couple of lines as example.
***002-cm-example.yaml***
```
apiVersion: v1
data:
  002-cm-example.conf: |
    hostname="myhost"
    port=1234
kind: ConfigMap
metadata:
  name: cm-example
  namespace: default
```

### Deploy the configMap
```
kubectl apply -f 002-cm-example.yaml
configmap/cm-example created

$ kubectl get cm
NAME               DATA   AGE
cm-example         1      7s

$ kubectl get cm cm-example -o yaml
apiVersion: v1
data:
  002-cm-example.conf: |
    hostname="myhost"
    port=1234
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"002-cm-example.conf":"hostname=\"myhost\"\nport=1234\n"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"cm-example","namespace":"default"}}
  creationTimestamp: "2022-01-18T08:51:59Z"
  name: cm-example
  namespace: default
  resourceVersion: "294203"
  uid: 19e5316d-c09d-4b3d-a74a-a46a496dbb35

```
We can use the configMap by mounting it as a volume into the POD

***002-cm-example-pod.yaml***
```
apiVersion: v1
kind: Pod
metadata:
  name: cm-example-pod
spec:
  containers:
  - name: cm-example
    image: k8s.gcr.io/busybox
    command: [ "/bin/sh", "-c", "watch -n 5 ls /etc/config/"]
    volumeMounts:
    - name: conf
      mountPath: /etc/config
  volumes:
  - name: conf
    configMap:
      name:  cm-example
      items:
      - key: 002-cm-example.conf
        path: default.conf
```
 
* Here the POD mount the volume named **conf** on **/etc/config**
* The volume **conf** is defined to reference a configMap named **cm-example**
* The data key **002-cm-example.conf** is mounted as a file named **default.conf**
* The result is that will have a file called **default.conf** mounted by the container under **/etc/config** and wich contains the configMap data

If we check the pod's logs we will see the the result 
```
$ kubectl logs cm-example-pod
Every 5s: ls /etc/config/                                   2022-01-18 10:13:29

default.conf

```

