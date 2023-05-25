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

## Range Vector Selectors
Allow to select data over a particular time range. 

```
Example:
```
node_cpu_seconds_total{cpu="0"}[2m] # select all values of the metric over last two minutes.
```

## Offset Modifier
It provide a time offset to select data from the past, with or without a range selector.  
Example:

Ge the amount of second of CPU used by the system from on hour ago
```
node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", mode="system"} offset 1h
```
Ge of second of CPU used by the system from on hour ago over a period of five minutes

```
node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", mode="system"}[5m] offset 1h 
```
