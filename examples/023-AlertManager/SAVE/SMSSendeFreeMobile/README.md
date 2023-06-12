# SMS Sender
In this example we deploy a SMS sender application that make use of the freemobile service notification for IOT devices.  
This SMS notification services is a free service for all freemobile subscribers that allow sending SMS notifications on the personal mobile from any devices internet connected.  
The Application will be used by other kubernetes microservices and for example by Prometheus to notify alerts.  
It consistes of simple httpd server that listen on port 9088 for a message to be sent to the fremobile service.
The REST API server by the application is **/send/<message>

The deployment will consists of
* a Secret holding the credentials to connect the freemobile SMS notification service.
* a deployment with the application specifications
* a service to expose the application to the other microservices
