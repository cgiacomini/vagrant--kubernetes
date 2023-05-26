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
## Query Functions
Prmetheus Query Language provivdes a set functions that give variety of built-in functionalities.
There are a lot of them so for a full list of PromQL functions have a look at the Prometheus the official documentation [Query Functions](https://prometheus.io/docs/prometheus/latest/querying/functions).  
Here are some examples:  

* **abs(instant-vector)** : returns the input vector with all sample values converted to their absolute value.
* **absent(instant-vector)** : returns a 1-element vector with the value 1 if the vector passed to it has no elements.
* **ceil()** : rounds the sample values of all elements in v up to the nearest integer.
* **clamp_max(instant-vector, scalar)** : clamps the sample values of all elements in v to have an upper limit of max.  
* **rate(v range-vector)** : calculates the per-second average rate of increase of the time series in the range-vector. Basically how fast/slow the time series is increasing.

Exmples **clamp_max**:

```
# The following query return the total cpu usage in seconds for the different modes since the server started up
node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100"}

node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="idle"}    2180.31
node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="iowait"}     6.87
node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="irq"}       64.78
node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="nice"}       2.36
node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="softirq"}   17.38
node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="steal"}         0
node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="system"}   102.57
node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="user"}     158.98

# Now we clamp the results to the maximu value of 1000
clamp_max(node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100"}, 1000)

# We see that all the values above 1000 have been substituted to 1000.
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="idle"}       1000
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="iowait"}     7.42
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="irq"}       70.88
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="nice"}       2.36
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="softirq"}   19.08
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="steal"}         0
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="system"}   112.49
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="user"}     173.7
```

Examples **rate**:
The rate function calculate the average rate of increase. So we can use it check the increase rate of the total numbers of seconds.
If that value is increasing rapidly then it means the the CPU usage in user mode is very high that point in time specified using the range specified.
```
# Get the icrease rate in the last hour
rate(node_cpu_seconds_total{cpu="0", instance="10.10.0.86:9100"}[1h])

# We see the increase rate is pretty low and it is in idle mode most of thime, that indicate a low cpu usage in the last hour.
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="idle"}    0.7934712036399604
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="iowait"}  0.0020663312594790635
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="irq"}     0.023118992947576654
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="nice"}    0.0006396449390042862
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="softirq"} 0.006349171285855588
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="steal"}   0
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="system"}  0.035703311856247935
{cpu="0", instance="10.10.0.86:9100", job="node-exporter", mode="user"}    0.053849760669304324
```
