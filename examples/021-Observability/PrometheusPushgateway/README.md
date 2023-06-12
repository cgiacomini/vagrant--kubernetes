# Prometheus Pushgateway

Prometheus server normally uses a pull method to collect metrics.
However, there are some use cases where a push method is necessary.
For example, in those cases where we want to have metrics for short-lived process or jobs.
Prometheus does not know when the process or jos started and died so to only possible way to get metrics is to push them from the job to prometheus when the job is running.

Prometheus Pushgateway serves as a middle-man forh these kind of usecases.
The jobs push te metrics to the pushgateway and then prometheus can pull thos metrics from the pushgatewy.
