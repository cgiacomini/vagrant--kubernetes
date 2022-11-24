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

# Check cronjob after 5 minutes. It says that 72s ago a job has been scheduled and executed
$ kubectl get cronjobs
NAME         SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
print-date   */5 * * * *   False     0        72s             6m8s

# One POD has been deployed
$ kubectl get pods
NAME                        READY   STATUS      RESTARTS   AGE
print-date-27371230-cl4h8   0/1     Completed   0          77s

# a job has started
$ kubectl get jobs
NAME                  COMPLETIONS   DURATION   AGE
print-date-27371230   1/1           33s        2m6s


# Check cronjob after 10 minutes. It says that 10s ago a job has been scheduled and executed
$ kubectl get cronjobs
NAME         SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
print-date   */5 * * * *   False     0        10s             10m

# A second POD has been deployed
$ kubectl get pods
NAME                        READY   STATUS      RESTARTS   AGE
print-date-27371230-cl4h8   0/1     Completed   0          5m15s
print-date-27371235-rrjlw   0/1     Completed   0          15s

# second job has been executed
$ kubectl get jobs
NAME                  COMPLETIONS   DURATION   AGE
print-date-27371230   1/1           33s        5m22s
print-date-27371235   1/1           2s         22s
```
