# Premetheus Architecture

![Architecture](../../doc/prometheus_architecture.png)

## General
Prometheus uses a pull based system that sends HTTP requests.   
Each request is called a ***scrape***, and is created according to the config instructions defined in your deployment file.   
Scraped data are stored by prometheus and can be queried via PromQL on the prometheus dashboard. 
Prometheus discovers targets to scrape from service discovery.  
Targets are instrumented applications then can be scraped via an exporter.  
Data can be also used to send alerts to the alert manager which in turn  could use them to produce different forms of notifications.

Prometheus provides four main types of metrics:

* Counter – Can be reset or incremented.
* Gauge – Can measure changes in either negative or positive directions. This metric is ideal for point-in-time values like memory use, in-progress requests, and temperature.
* Histogram – Can sample and categorize events with a total sum of all observed values. This metric is ideal for data aggregation.
* Summary – Can support histogram metrics, and also calculate quantiles over a sliding time window according to the total event sums and counts of observed values. This metric is ideal for generating an accurate quantile range.

All the data are stored as time series identified by a metric name and a set of key-value pairs called labels:
```
<metric name>{<label_1 name>=<label_1 value>, ..., <label_n name>=<label_n value>} <value>
```
Each sample of a time series consists of a float64 value and a millisecond-precision timestamp.

## Client Libraries
here are two ways in which Prometheus can access data:
* either directly from the client libraries of your applications
* or indirectly through exporters.

Client Libraries are used to instruments the applications to produce metrics.  
Available for many languages, they take care of the details for producing metrics and respond t http requests.

## Exporters
Like SNMP agents, exporters are responsible to collect metrics data and expose them to Prometheus whenever there no direct instrumentation.
basically are kind of proxy that receive requests, collect the required information and return them in the correct expected format.  
You can use exporters to access data you do not have control over, such as kernel metrics.

## Service Discovery
Prometheus service discovery is a standard method of finding endpoints to scrape for metrics.
With Service Discovery we provide to prometheus the necessary information to find the exporters or direct metrics provider.

# Scraping
Service discovery and relabeling give us a list of targets to be monitored. Prometheus fetch metrics by sending HTTP requests (scrape).  
The response to a scrape (an http request) is parsed and stored. 

# Storage
Data are stored locally in a custum database 

# The Dashboard
Allow to query stored metirics in a raw format or in a more complex way using promql


# Rules and Alerts
PromQL expressions can be evaluated on e regular basis and their result to be stored in the database.


# Alert Monitoring 
The Alert Manager receives alerts from Prometheus servers and turn them into notifications.
