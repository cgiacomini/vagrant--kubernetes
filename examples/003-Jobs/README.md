# Kubernete Jobs
* Pods normally are created to run forever.
* To create a POD that runs a limited duration we use jobs instead.
* Jobs are useful for tasks like backup, calculation, batch processing etc.
* A POD that is started by a Job must have its restartPolicy set to **OnFailure** or **Never**.
    * ***OnFailure*** we re-run the container in the same POD
    * ***Never*** will re-run the failing container in a new POD.
* There are three different Jobs types:
    * ***non parallel jobs***:
        * completions=1
        * parallelism=1
    * ***parallel jobs with a fixed completion count***: the job is completed after successfully running as many time as specified in jobs.spec.completions.
        * completions=n - how many
        * parallelism=m  - how many in parallel
    * ***parallel jobs with a work queue***: multiple jobs started, when a job complete successfully, the job is completed.
        * completions=1
        * parallelism=m  - how many jobs in parallel
* Other Job properties
    * ***spec.backoffLimit*** : specify the number of retries before considering a Job as failed.

## Example 1 - 
***001-SimpleJob.yaml***
```
apiVersion: batch/v1
kind: Job
metadata:
  name: simple-job
spec:
  template:
    spec:
      containers:
      - name: sleepy
        image: alpine
        command: ["/bin/sleep" ]
        args: [ "5" ]
      restartPolicy: Never
```
## Explanation
In starting the jobs Kubernetes will start a POD  as specified in the template.
The job is executed once and then it will never start again as specified in **restartPolicy** property.
```
# Create the Job
$ kubectl create -f 001-SimpleJob.yaml
job.batch/simple-job created
# We see the job has started but not yet completed
$ kubectl get jobs
NAME         COMPLETIONS   DURATION   AGE
simple-job   0/1           7s         7s

# After few seconds the job is completed
$ kubectl get jobs
NAME         COMPLETIONS   DURATION   AGE
simple-job   1/1           9s         9s

# We can see the the POD in which the job has been executed is  marked as completed.
$ kubectl get pods
NAME                  READY   STATUS      RESTARTS   AGE
simple-job--1-sbbsq   0/1     Completed   0          29s
```
## Example 2
Now we add the completions property and run it again.
We should have three completed jobs and corresponding PODs running and then completed.
***002-SimpleJob.yaml***
```
apiVersion: batch/v1
kind: Job
metadata:
  name: simple-job
spec:
  completions: 3
  template:
    spec:
      containers:
      - name: spleepy
        image: alpine
        command: ["/bin/sleep" ]
        args: [ "5" ]
      restartPolicy: Never
```
In creating the jobs we see after a while that the job has been executed 3 times. 
For this it spawned 3 different PODs  to run the on job in each of them.
```
$ kubectl apply -f 002-SimpleJob.yaml
$ kubectl get jobs
NAME         COMPLETIONS   DURATION   AGE
simple-job   0/3           10s        10s
$ kubectl get job
NAME         COMPLETIONS   DURATION   AGE
simple-job   1/3           26s        26s
$ kubectl get jobs
NAME         COMPLETIONS   DURATION   AGE
simple-job   3/3           27s        27s
$ kubectl get pods
NAME               READY   STATUS      RESTARTS   AGE
simple-job-282tx   0/1     Completed   0          41s
simple-job-mp8wk   0/1     Completed   0          31s
simple-job-p522x   0/1     Completed   0          22s
```
