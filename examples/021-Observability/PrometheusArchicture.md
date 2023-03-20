# Premetheus Architecture

![Architecture](../../doc/prometheus_architecture.md)

## General
Prometheus discovers targets to scrape from service discovery. Targets are instrumented applications thet can be scraped via an exporter.  
Scraped data are stored by prometheus and can be queried via PromQL on the prometheus dashboard. Data can be also used t send alerts to
the alert manager which in turn  could use them to produce different forms of notifications.

## Client Libraries
Client Libraries are used to instruments the applications to produce metrics.  
Available for many different languages, they take care of the details for producing metrics and respond t http requests.

## Exporters
Like SNMP agents, exporters they are responsible to collect metrics data and expose them to prometheus whenever there no direct instrumentation.
basically are kind of proxy that receive requests, collect the required information and return them in the correct expected format.

## Service Discovery
Prometheus service discovery is a standard method of finding endpoints to scrape for metrics.
With Service Discovery we provide to prometheus the necessary information to find the exporters or direct metrics provider.

# Scraping
Service discovery and relabeling give us a list of targets to be monitored. Prometheus fetch metrics by sending HTTP requests (scrape).  
The response to a scrape (an http request) is parsed and stored. Prometheus is configure to pull metrics but a monitoring targer can also 
push information about if and when is going to be monitored


# Storage
Data are stored locally in a custum database 

# The Dashboard
Allow to query stored metirics in a raw format or in a more complex way using promql


# Rules and Alerts
PromQL expressions can be evaluated on e regular basis and their result to be stored in the database.


# Alert Monitoring 
The Alert Manager receives alerts from Prometheus servers and turn them into notifications.
