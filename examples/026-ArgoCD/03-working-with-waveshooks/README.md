# Argo CD Syncwaves and Hooks
## Introduction
[**REF**: https://kubebyexample.com/learning-paths/argo-cd/argo-cd-syncwaves-and-hooks]

*Syncwaves* are used in Argo CD to order how manifests are applied to the cluster.  
Whereas *resource hooks* breaks up the delivery of these manifests in different phases.
Using the combination of *syncwaves* and *resources hooks* we can control how an apllication is rolled out.


The sample application that we will deploy is a **todo** application with a database, syncwaves and resource hooks are used:
![Deployment example](../../../doc/argocdSyncWavesResourceHooks1.JPG)

All manifests have a wave of zero by default, but you can set these by using the *argocd.argoproj.io/sync-wave* annotation.

Example:
```
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

The wave can also be negative as well.

```
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
```

When Argo CD starts a sync action, the manifest get placed in the following order:

+ The **Phase** that they're in (PreSync, Sync and PostSync)
+ The wave the resource is annotated in (starting from the lowest value to the highest)
+ By kind (Namspaces first, then services, then deployments, etc ...)
+ By name (ascending order)


Controlling your sync operation can be futher redefined by using hooks. These hooks can run before, during, and after a sync operation.

These hooks are:

+ ***PreSync***:  Runs before the sync operation. This can be something like a database backup before a schema change
+ ***Sync***:     Runs after PreSync has successfully ran. This will run alongside your normal manifests.
+ ***PostSync***: Runs after Sync has ran successfully. This can be something like a Slack message or an email notification.
+ ***SyncFail***: Runs if the Sync operation as failed. This is also used to send notifications or do other evasive actions.

To enable a sync, annotate the specific object manifest with ***argocd.argoproj.io/hook*** with the type of sync you want to use for that resource.
For example, if we want to use the PreSync hook:

```
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
```
You can also have the hooks deleted after a successful/unsuccessful run.

+ ***HookSucceeded***": The resource will be deleted after it has succeeded.
+ ***HookFailed***: The resource will be deleted if it has failed.
+ ***BeforeHookCreation***: The resource will be deleted before a new one is created (when a new sync is triggered).

You can apply these with the ***argocd.argoproj.io/hook-delete-policy*** annotation. For example

```
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

## Using Syncwaves and Hooks
*presync.yaml* : This manifest is annotated with ***argocd.argoproj.io/hook: PreSync*** and therefore is execute first before the ArgoCD Sync phase. It also hase ***argocd.argoproj.io/sync-wave: "0"*** annotation ( also is the default value )
*namespace.yaml*: The namespace manifest will processed next because it's in the "Sync" phase (the default when no annotation is present), and it is in wave 0 as indicated with the annotation argocd.argoproj.io/sync-wave: "0"
*deployment.yaml*:  The deployment manifest is processed after the namespace one because it's annotated with argocd.argoproj.io/sync-wave: "1"
*service.yaml*: Finally, the service gets deployed as it's annotated with argocd.argoproj.io/sync-wave: "2"

### presync.yaml
This will run a dummy PreSync script using the RedHat Universal Base Image (**ubi**) which is designed and engineered to be the base layer for all of your containerized applications, middleware and utilities.   
The script just sleep for 3 seconds and echo "Presync". We could use a Job for this instead of a POD but this is just for demonstration purpose.

```
---
apiVersion: v1
kind: Pod
metadata:
  name: presync-pod
  namespace: synctest
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    argocd.argoproj.io/hook: PreSync
  labels:
    app.kubernetes.io/name: presync-pod
spec:
  containers:
  - name: myapp-container
    image: registry.access.redhat.com/ubi8/ubi
    command: ['bash', '-c', 'sleep 3 ; echo Presync']
    imagePullPolicy: Always
  restartPolicy: "Never"

```

### namespace.yaml
```
---
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  name: synctest
spec: {}
```

### deployment.yaml
Here we deploy an **initContainer**  which runs simple application. The BGD application is an example web application that just shows a color (blue by default).  
The initContainer is just for demostration purpose it run a sleep command for 5 seconds. Once fineshed the application container start. 
The application will be in ready status when the readinessProbe  (an http get on port 8080 ) will succeed. The livenvessProbe wil check the application status.

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    app: bgd
  name: bgd
  namespace: synctest
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bgd
  strategy: {}
  template:
    metadata:
      labels:
        app: bgd
    spec:
      initContainers:
      - name: init-bgd
        image: quay.io/redhatworkshops/bgd
        command: ['bash', '-c', "sleep 5"]
        imagePullPolicy: Always
      containers:
      - image: quay.io/redhatworkshops/bgd
        name: bgd
        imagePullPolicy: Always
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 2
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 3
        resources: {}
```

### service.yaml
The service having the sync-wave set to "2" will be deployed as last

```
---
apiVersion: v1
kind: Service
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  labels:
    app: bgd
  name: bgd
  namespace: synctest
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: bgd
```
