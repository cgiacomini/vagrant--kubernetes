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

### Label Matching
Query can be more sophisticated by using a variety of operator to perform label values matching.  
Examples:  
```
node_cpu_seconds_total{cpu="0"}    # =  Equals
node_cpu_seconds_total{cpu!="0"}   # != Not Equal
node_cpu_seconds_total{cpu=~"1*"}  # RegEx Match
node_cpu_seconds_total{cpu=!~"1*"} # RegEx Not Match

node_cpu_seconds_total{mode=~"user|system"} # Get metrics for user and system only
node_cpu_seconds_total{mode=~"s.*"}         # Get metrics for all modes starting with "s"
```
### Range Vector Selectors
Allow to select data over a particular time range.  
Example:
```
node_cpu_seconds_total{cpu="0"}[2m] # select all values of the metric over last two minutes.
```

### Offset Modifier
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
## Query Operators
These are operator that allow to perform calculations based on the metric data.  
### Arithmetic Binary Operators
Using these operators we can perform basic aritmetic operation on metrics numeric:
* "+" : Addition
* "-" : Subtration
* "*" : Multiplication
* "/" : Division
* "%" : Modulo
* "^" : Exponentiation

Examples:
```
node_cp_seconds_total * 2  # Multiply the metric valu by 2
```
What if we would like to get the total ammout of CPU usage for system and user time of cpu=0 of a particular node for example instance="10.10.0.82:9100"?
We could try something like this
```
node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", mode="user"} + node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", mode="system"}"
```
Unfortunatelly the result is not what we expect. This is because of ***Matching Rules***

### Matching Rules
whenever we use *operators* prometheus uses *Matching Rules* to determine how to combine or compare values from a dataset.  
By default values can be combined or compare if all their labels match.  
To controll the matching rule behaviour we can use the the followin *keywords*  

* **ignoring**(label list) : Ignore the specified label matching
* **on**(label list) : Use only specified labels when matching
  
Examples:  
We get the sum of the two mode cpu usage
```
node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", mode="user"} + ignoring(mode) node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", mode="system"}"
{cpu="0", instance="10.10.0.82:9100", job="node-exporter"}   508.67999999999995
```
Or alterantivelly
```
node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", mode="user"} + on(cpu) node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", mode="system"}
{cpu="0"} 508.67999999999995
```

### Comparison Binary Operators
These operators are used to filter results to only those where the comparison expression evaluates to true.  

* "==" : Equal
* "!=" : Not Equal
* ">" : Greater than
* "<" : Less than
* ">=" : Greater than or Equal
* "<=" : Less then or equal
  
Examples:  
In The following example we select the node_cpu_seconds_total  metrics that has a value of 0.  
We see that the cpus 0 and 1 on all nodes has usage of 0 seconds in steal mode.
```
node_cpu_seconds_total == 0

node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="steal"}   0
node_cpu_seconds_total{cpu="0", instance="10.10.1.251:9100", job="node-exporter", mode="steal"}  0
node_cpu_seconds_total{cpu="0", instance="10.10.2.58:9100", job="node-exporter", mode="steal"}   0
node_cpu_seconds_total{cpu="1", instance="10.10.0.82:9100", job="node-exporter", mode="steal"}   0
node_cpu_seconds_total{cpu="1", instance="10.10.1.251:9100", job="node-exporter", mode="steal"}  0
node_cpu_seconds_total{cpu="1", instance="10.10.2.58:9100", job="node-exporter", mode="steal"}   0
```

Here we ask to return true (1) of false (0) when for node_cpu_seconds_total for cpu 0 on node 10.10.0.82 its value is equal 0.  
We can see that only for mode="steal" the result is true.
```
node_cpu_seconds_total{cpu="0", instance="10.10.0.82:9100"} == bool 0

{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="idle"}    0
{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="iowait"}  0
{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="irq"}     0
{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="nice"}    0
{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="softirq"} 0
{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="steal"}   1
{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="system"}  0
{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="user"}    0
```

### Logical Set Binary Operators
These operators are used to combine set of results in varius ways by using labels to compare metric values.  
* "and"
* "or"
* "unless"

Examples:  
Here we ask to return a combination of results using *and* operator for two metrics that have similar but not all matching labels values.
**node_cpu_seconds_total** have modes: *idle, iowait, irq, nice sofirq, steal, system, user* while **node_cpu_seconds_total** has only modes: *users, nice*.
By combining them using *and* operator we only get the metrics for the two modes *user* and *nice* in both the metrics.
```
node_cpu_seconds_total and node_cpu_guest_seconds_total
node_cpu_guest_seconds_total{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="nice"}  0
node_cpu_guest_seconds_total{cpu="0", instance="10.10.0.82:9100", job="node-exporter", mode="user"}  0
node_cpu_guest_seconds_total{cpu="0", instance="10.10.1.251:9100", job="node-exporter", mode="nice"} 0
node_cpu_guest_seconds_total{cpu="0", instance="10.10.1.251:9100", job="node-exporter", mode="user"} 0
node_cpu_guest_seconds_total{cpu="0", instance="10.10.2.58:9100", job="node-exporter", mode="nice"}  0
node_cpu_guest_seconds_total{cpu="0", instance="10.10.2.58:9100", job="node-exporter", mode="user"}  0
node_cpu_guest_seconds_total{cpu="1", instance="10.10.0.82:9100", job="node-exporter", mode="nice"}  0
node_cpu_guest_seconds_total{cpu="1", instance="10.10.0.82:9100", job="node-exporter", mode="user"}  0
node_cpu_guest_seconds_total{cpu="1", instance="10.10.1.251:9100", job="node-exporter", mode="nice"} 0
node_cpu_guest_seconds_total{cpu="1", instance="10.10.1.251:9100", job="node-exporter", mode="user"} 0
node_cpu_guest_seconds_total{cpu="1", instance="10.10.2.58:9100", job="node-exporter", mode="nice"}  0
node_cpu_guest_seconds_total{cpu="1", instance="10.10.2.58:9100", job="node-exporter", mode="user"}  0
```

### Agregation Operators
Are used to combine multiple values into a single value.  
* "sum" : add values all together
* "min" : return the smalest value
* "avg" : return the avarage value
* "stddev" : return the standard deviation
* "stdvar" : return the standard variance
* "count" : return the number of values
* "count_values" : return the number of values with the same value
* "bottomk" : return the smallets number of elements
* "topk" : return the largest number of elements
* "quantile" : return the quantile for a particular dimension

Examples:  
The following query uses the avg operator to get the avarage users cpu time from all the nodes 
```
avg(node_cpu_seconds_total{mode="user"})
{} 1096.715
```
