# Querying
Prometheus PromSQL allow to work and use metric data collected by prometheus by writing queries to retrieve useful informations.  

Queries can be done via :

* Prometheus Dashboard
* Prometheus HTTP REST API
* Visualization tools such as Grafana

## Selectors
The most basic component of PromSQL is a **time-series selector**.   
Basically a metric name, optionally combined with labels.  
Examples:
```
node_cpu_seconds_total
node_cpu_seconds_total{cpu="0"}
```

## Label Matching
Query can be more sophisticated by using a variety of operator to perform label values matching.  
Examples:  
```
node_cpu_seconds_total{cpu="0"}    # =  Equals
node_cpu_seconds_total{cpu!="0"}   # != Not Equal
node_cpu_seconds_total{cpu=~"1*"}  # RegEx Match
node_cpu_seconds_total{cpu=!~"1*"} # RegEx Not Match

node_cpu_seconds_total{mode=~"user|system"} # Get metrics for user and system only
node_cpu_seconds_total{mode=~"s.*"}         # Get metrics for all modes starting with "s"
