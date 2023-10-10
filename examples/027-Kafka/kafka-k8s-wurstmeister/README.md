# Kubernetee Kafka cluster deployment with zookeeper

In its simplest example, we are going to install kafka in our 3 nodes kubernetes cluster.

## creating the namespace

First we define a namespace where we deploy our kafka cluster defined by the following manifest YAML file:

***kafka-namespace.yaml***
```
apiVersion: v1
kind: Namespace
metadata:
  name: kafka
spec:
  finalizers:
  - kubernetes
status:
  phase: Active
```
  
```
$ kubectl apply -f kafka-namespace.yaml
namespace/kafka created

$ kubectl config set-context --current --namespace=kafka
Context "kubernetes-admin@kubernetes" modified.

```

## Zookeeper Deployment
We could deploy kafka in kraft mode in zookeeperless mode, but here I have decided to explore the zzookeeper way.
One instance of zookeeper is deployed along with a service to access it.

***kafka-zookeeper.yaml***
```
apiVersion: v1
kind: Service
metadata:
  labels:
    app: zookeeper-service
  name: zookeeper-service
  namespace: kafka
spec:
  type: NodePort
  ports:
    - name: zookeeper-port
      port: 2181
      nodePort: 30181
      targetPort: 2181
  selector:
    app: zookeeper
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: zookeeper
  name: zookeeper
  namespace: kafka
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zookeeper
  template:
    metadata:
      labels:
        app: zookeeper
    spec:
      containers:
        - image: wurstmeister/zookeeper
          imagePullPolicy: IfNotPresent
          name: zookeeper
          ports:
            - containerPort: 2181
```

Here we deploy one instance of zookeeper and in front of it a NodePort Service which expose port 30181. Nothing new so far.

```
$ kubectl apply -f kafka-zookeeper.yaml
service/zookeeper-service created
deployment.apps/zookeeper created

$ kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
zookeeper-654bbcd6cc-d8qr5   1/1     Running   0          15s

$ kubectl get service
NAME                TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
zookeeper-service   NodePort   10.105.5.150   <none>        2181:30181/TCP   44s
```
This service needs to be communicated to the kafka brokers to tell them where to listen for it.


## Kafka cluster deployment
Here for demonstration purpose we deploy a two brokers kafka cluster knowing that a minimum of three brokers is recommended.

***kafka-cluster.yaml***
```
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: kafka-broker
  name: kafka-service
  namespace: kafka
spec:
  selector:
    app: kafka-broker
  type: NodePort
  ports:
  - port: 9092
    targetPort: 9092
    nodePort: 30092
---
apiVersion: apps/v1
kind: statefullSet
metadata:
  labels:
    app: kafka-broker
  name: kafka-broker
  namespace: kafka
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kafka-broker
  template:
    metadata:
      labels:
        app: kafka-broker
    spec:
      hostname: kafka-broker
      containers:
      - env:
        - name: KAFKA_BROKER_ID
          value: "1"
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: zookeeprt-service.kafka.svc.cluster.local:2181
        - name: KAFKA_LISTENERS
          value: PLAINTEXT://:9092
        - name: KAFKA_ADVERTISED_LISTENERS
          value: PLAINTEXT://:9092
        image: wurstmeister/kafka
        imagePullPolicy: IfNotPresent
        name: kafka-broker
        ports:
        - containerPort: 9092
```

## Testing Kafaka Topics
There are several way to do this test, for example by using *kafkacat* command, but for now we stick on the utilities available inside the deployed broker's containers.

### Create a topic and insert some event messages:
Using kafka-broker-0 we create a topic
```
$ kubectl exec kafka-broker-0 -it -- /opt/kafka/bin/kafka-topics.sh --create --topic my-topic --bootstrap-server localhost:9092
```
### verify topic a topic and insert some event messages:
```
$ kubectl exec kafka-broker-0 -it -- /opt/kafka/bin/kafka-topics.sh --describe --topic my-topic --bootstrap-server localhost:9092
Topic: quickstart-events        TopicId: 8wmkH2cBS9yzaa1g8bmmjw PartitionCount: 1       ReplicationFactor: 1    Configs: segment.bytes=1073741824
        Topic: my-topic        Partition: 0    Leader: 1002    Replicas: 1002  Isr: 1002
```
### create a message inside the topic
```
$ kubectl exec kafka-broker-0 -it -- /opt/kafka/bin/kafka-console-producer.sh --topic my-topic --bootstrap-server localhost:9092
> this my first message
> this my second message
```
do a CRTL-C do finish the insertion


### Get the event messages from the topic
This time from the second proker kafka-broke-1 we read from the topic
```
$ kubectl exec kafka-broker-1 -it -- /opt/kafka/bin/kafka-console-consumer.sh --topic my-topic --from-beginning --bootstrap-server localhost:9092
this my first message
this is my second message
```
do a CTRL-C to stop reading

