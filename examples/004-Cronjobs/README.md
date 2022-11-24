# CronJobs
CronJobs are used for tasks that need to run on a regular basic at a specific time.
When running a CronJob a Job will be scheduled and when it start it run a POD.
## Example 1
We create a cron job which runs every 5 minutes.  
***001-SimpleCronJob.yaml***
```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: "hello-cronjob"
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo hello from k8s cluster
          restartPolicy: OnFailure
```
The job is scheduled to run every 5 minutes, when scheduled it start a POD which runs the described bash commands
```
# Deploy the cronjob
$ kubectl apply -f 001-SimpleCronJob.yaml
cronjob.batch/print-date created

# Check cronjob after 5 minutes. It says that 65s ago a job has been scheduled and executed
$ kubectl get cronjobs
NAME            SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
hello-cronjob   */5 * * * *   False     0        65s             4m36s

# One POD has been deployed
$ kubectl get pods
NAME                           READY   STATUS      RESTARTS      AGE
hello-cronjob-27821340-9h5j5   0/1     Completed   0             93s

# a job has started
$ kubectl get jobs
NAME                     COMPLETIONS   DURATION   AGE
hello-cronjob-27821340   1/1           6s         2m18s

# Check cronjob after 10 minutes. It says that 10s ago a job has been scheduled and executed
$ kubectl get cronjobs
NAME            SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
hello-cronjob   */5 * * * *   False     0        13s             8m44s

# second job has been executed
$ kubectl get jobs
NAME                     COMPLETIONS   DURATION   AGE
hello-cronjob-27821340   1/1           6s         5m27s
hello-cronjob-27821345   1/1           5s         27s

# A second POD has been deployed
$ kubectl get pods
NAME                           READY   STATUS      RESTARTS      AGE
hello-cronjob-27821340-9h5j5   0/1     Completed   0             5m31s
hello-cronjob-27821345-dz4lf   0/1     Completed   0             31s
side-car-pod                   2/2     Running     2 (81m ago)   19h
```
