# Kafka Connect

# Introduction
***Connectors*** - Jar files
***Tasks*** - Connectors + ***User Configuration***.
***Workers*** - Tasks are executed by Kafka Connect *Workers*. A Worker is a single Java process. It can be ***Standalone*** or ***Distributed*** in a cluster.

+ *Standalone* (more for dev) -  A single process run your connectors and tasks, the configuration is bundled with the process.
+ *Distributed* (for production) - Multiple workers run the connectors and taks. The configuration is submited with REST API.

## Building a Kafka Connect Environment


The Kafka distribution contains the Kafka Connect scripts and JAR files needed to start a Kafka Connect cluster.
+ The Kafka Connect JAR files in the libs folder of the Kafka distribution. This includes the runtime JAR file, but also files it depends on, like the Kafka clients’ JAR.
+ The ***connect-distributed.sh*** script in the bin folder of the Kafka distribution (or connect-distributed.bat from bin/windows if running on Windows operating system).
+ The ***kafka-run-class.sh*** script in the bin folder of the Kafka distribution (or kafka-run-class.bat from bin/windows if running on Windows operating system), since this is invoked by the connect-distributed script.


In addition to these files, you also need available in your Kafka Connect environment:
+ A configuration file for each Kafka Connect worker using the properties format. The config folder of the Kafka distribution includes an example called ***connect-distributed.properties.***
+ A configuration file for the logging for each Kafka Connect worker using the properties format. The config folder of the Kafka distribution includes an example called ***connect-log4j.properties***.
+ The JAR files for the connector and worker plug-ins you want to use (see the next section for more on worker plug-ins).

Developers choose to deploy Kafka Connect workers as containerized applications on platforms like Kubernetes.  If you want to run your Kafka Connect workers as containers, you can either 
+ create the container image yourself, 
+ use one from the community,
+ or purchase proprietary software that provides one.

My choice is to reuse the same image I have used to run the kafka cluster but adding the required connector JAR is missing and overriding the container ENTRYPOINT

> Dockerfile has a parameter for ENTRYPOINT and while writing Kubernetes deployment YAML file, there is a parameter in Container spec for COMMAND.
> When you override the default Entrypoint and Cmd in Kubernetes YAML file, these rules apply:
> + If you do not supply command or args for a Container, the defaults defined in the Docker image are used.
> + If you supply only args for a Container, the default Entrypoint defined in the Docker image is run with the args that you supplied.
> + If you supply a command for a Container, only the supplied command is used. The default EntryPoint and the default Cmd defined in the Docker image are ignored.  Your command is run with the args supplied (or no args if none supplied).

Basicaly what we will do is to run the image by telling it to start the kafka connectore in distributed mode by executing the ***/opt/kafka/bin/connect-distributed.sh***

We need to make sure that :
+ the kafka image we use has */opt/kafka/config/connect-distributed.properties* file with the *plugin.path* pointing to the directory where we actually have the connectors JAR file installed. In the image we are using the connectors JAR files are located in */opt/kafka/lib*
+ *connect-distributed.properties* has ***rest.port=8083*** property to allow us to create connectors via REST API for demonstration purpose.  Normally we insted provide the *connect-distributed.sh* script a ***worker.properties*** file with all the details about the connector.


sed -i -e 's|#plugin.path=|plugin.path=/opt/kafka/libs|' connect-distributed.properties
sed -i -e 's|#rest.port=8083|rest.port=8083|' connect-distributed.properties
kubectl copy worker.properties file in  /opt/kafka/config  ( there are already some example for example  connect-file-source.properties connect-file-sink.properties 

so to start the connector  for example for a sink connector (to file)
/opt/kafka/bin/connect-standalone.sh   connect-standalone.properties connect-file-sink.properties
/opt/kafka/bin/connect-distributed.sh  connect-distributed.properties  connect-file-sink.properties


get existing connector and deleting examples
$ curl GET http://<pod-ip-nodeport-etc>:8083/connectors/<name of the connector>
$ curl GET http://<pod-ip-nodeport-etc>:8083/connectors/<name of the connector>/status
$ curl DELETE http://<pod-ip-nodeport-etc>:8083/connectors/<name of the connector>

$ kubectl exec kafka-broker-0 -n kafka -it -- /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092
__consumer_offsets
kafka-connect-cp-kafka-connect-config
kafka-connect-cp-kafka-connect-offset
kafka-connect-cp-kafka-connect-status
