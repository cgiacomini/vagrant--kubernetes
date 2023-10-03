# Deploy Kafka in docker

## Example
Here we are going to deploy zookeeper and Kafka using docker to do so we use the following ***docker-compose.yaml*** file:
```
connector version: "3"
services:
  zookeeper:
    image: wurstmeister/zookeeper
    ports:
      - "2181:2181"
  kafka:
    image: wurstmeister/kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_ADVERTISED_HOST_NAME: localhost
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
```
Here we define a single Zookeeper and Kafka node just for experiment purpose. The Zookeeper node simply expose port 2181. Kafka node is exposing 9092 port and also is configure with the following environment variables :
+ KAFKA_ADVERTISED_HOST_NAME – Should match the docker host IP
+ KAFKA_ZOOKEEPER_CONNECT - Instructs Kafka how to get in touch with ZooKeeper.

For an explanation of the network connectivity have a look to: https://github.com/wurstmeister/kafka-docker/wiki/Connectivity
```
$ docker-compose -f docker-compose.yml up
Creating network "kafka-nodejs_default" with the default driver
Creating kafka-nodejs_kafka_1     ... done
Creating kafka-nodejs_zookeeper_1 ... done
Attaching to kafka-nodejs_kafka_1, kafka-nodejs_zookeeper_1
kafka_1      | [Configuring] 'port' in '/opt/kafka/config/server.properties'
kafka_1      | [Configuring] 'advertised.host.name' in '/opt/kafka/config/server.properties'
kafka_1      | Excluding KAFKA_HOME from broker config
kafka_1      | [Configuring] 'log.dirs' in '/opt/kafka/config/server.properties'
kafka_1      | Excluding KAFKA_VERSION from broker config
kafka_1      | [Configuring] 'zookeeper.connect' in '/opt/kafka/config/server.properties'
kafka_1      | [Configuring] 'broker.id' in '/opt/kafka/config/server.properties'
zookeeper_1  | ZooKeeper JMX enabled by default
zookeeper_1  | Using config: /opt/zookeeper-3.4.13/bin/../conf/zoo.cfg
…
…
```

As we see docker create as subnetwork kafka-nodejs_default for the two containers to communicate:
```
$ docker network list
NETWORK ID     NAME             DRIVER    SCOPE
6849f867f71d   bridge           bridge    local
d2ca9885c5c2   host                     host      local
c9cc044b5d8d   kafka-nodejs_defaul      bridge    local
df329dc9b341   kind                     bridge    local
```
Now we can try to create a topic in Kafka using a JavaScript example. For this to work we need to have NodeJS installed and the kafkajs mod-ule installed.
```
$ npm instal kafkajs
up to date, audited 2 packages in 741ms
found 0 vulnerabilities
```

We can now create a topic “Users”: ***topic.js***
```
const { Kafka } = require("kafkajs");

run();
async function run() {
  try {
    const kafka = new Kafka({
      clientId: "myapp",
      brokers: ["127.0.0.1:9092"],
    });

    const admin = kafka.admin();
    await admin.connect();
    console.log("Admin connected!");
    await admin.createTopics({
      topics: [
        {
          topic: "Users1",
          numPartitions: 2,
          replicationFactor: 1,
        },
      ],
    });
    console.log("Topic created successfully!");
    await admin.disconnect();
  } catch (err) {
    console.log(err);
  } finally {
    process.exit(1);
  }
}
```

***Output***:
```
$ node topic.js
Admin connected!
Topic created successfully!
```

And run the producer to insert a message inside the User topic: ***producer.js***
```
const { Kafka } = require("kafkajs");
const msg = process.argv[2];

run();
async function run() {
  try {
    const kafka = new Kafka({
      clientId: "myapp",
      brokers: ["127.0.0.1:9092"],
    });

    const producer = kafka.producer();
    await producer.connect();
    console.log("Producer connected!");

    // A-M partition 0, N-Z partition 1
    const partition = msg[0] < "N" ? 0 : 1;
    console.log("Partition: ", partition);
    const result = await producer.send({
      topic: "Users1", // Users1 has 2 partitions, Users has 1 partition
      messages: [
        {
          value: msg,
          partition: partition,
        },
      ],
    });
    console.log("Produced successfully!", result);
    await producer.disconnect();
  } catch (err) {
    console.log(err);
  } finally {
    process.exit(1);
  }
}
```
***Output:***
```
$  node producer.js  "My Messag Here"
Producer connected!
Partition:  0
Produced successfully! [
  {
    topicName: 'Users1',
    partition: 0,
    errorCode: 0,
    baseOffset: '0',
    logAppendTime: '-1',
    logStartOffset: '0'
  }
]
```

Verify We get the message from the topic Users using a Kafka ***consumer.js***:
```
const { Kafka } = require("kafkajs");
const msg = process.argv[2];

run();
async function run() {
  try {
    const kafka = new Kafka({
      clientId: "myapp",
      brokers: ["127.0.0.1:9092"],
    });

    const consumer = kafka.consumer({ groupId: "testGroup" });
    await consumer.connect();
    console.log("Consumer connected!");
    consumer.subscribe({
      topic: "Users1",
      fromBeginning: true,
    });

    await consumer.run({
      eachMessage: async (result) => {
        console.log(
          `Received message: ${result.message.value} on partition: ${result.partition}.`
        );
      },
    });

    console.log("Consumed successfully");
  } catch (err) {
    console.log(err);
  } finally {
    // process.exit(1);
  }
}
```
***Output:***
```
$  node consumer.js
Consumer connected!
…
02T08:58:26.508Z","logger":"kafkajs","message":"[ConsumerGroup] Consumer has joined the group","groupId":"testGroup","memberId":"myapp-ac05f22a-abb8-42f3-b137-1f294e1143ec","leaderId":"myapp-ac05f22a-abb8-42f3-b137-1f294e1143ec","isLeader":true,"memberAssignment":{"Users1":[0,1]},"groupProtocol":"RoundRobinAssigner","duration":1001}
Consumed successfully
Received message: My Messag Here on partition: 0.
