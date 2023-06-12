# Prometheus High Availabilty

High-availability systems are systems that are resilient to failure.
With a high-availability system, you can have multiple Prometheus servers so if one of them goes down, you still have other Prometheus servers available.  
Alertmanager allows you to build a cluster where multiple Alertmanagers will communicate with each other and coordinate with each other, but Prometheus doesn't allow you to do that.  
To fullfil High availability with Prometheus is however quite straightforward. We just need to setup multiple prometheus servers with the same configuration.  
Each separate Prometheus servers can just be separately pulling metrics from the same set of underlying services.  

# Prometheus Federation 

Federation is the process of having one Prometheus server scraping some or all time-series data from another Prometheus server. 
With federation we share metric data between multiple Prometheus servers. There are two kind of federation.

* ***Hierarcgical Federation*** : We have higher level Prometheus servers that collect metrics data from multiple lower lever prometheus servers. The higer level server agregate for example the data from lower servers.
* ***Cross-Service Federation*** : We have for example a Prometheus server monitoring a service or a set of services data, that also scrape data from other prometheus server monitoring different services data. This way we can combine metrics data and alerts.

!([Nice Article](https://logz.io/blog/devops/prometheus-architecture-at-scale/)

## Federation configuration
Federation can be setup by configuring a Prometheus server to scrape the ***/federate*** endpoint on another prometheus server.
example :
```
scrape_configs:

- job_name : 'federate'
  scrape_interval: 15s
  # Preserve the original labels of data from the target prometheus
  honor_labels: true
  metrics_path: '/federate'
  params:
     # Get all data excluding the target prometheus metrics data
     'match[]':
        - '{job!~prometheus}'
  staic_configs:
  - targets:
     - '<target prometheus to federetate with>:9090'
```
