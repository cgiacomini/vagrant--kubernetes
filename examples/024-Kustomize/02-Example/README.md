# What is Kustomize?
***REF***: [ https://dev.to/mxglt/what-is-kustomize--3pn5 ]

Kustomize is a configuration management tool embeded in Kubernetes!
So if you already have kubectl setup, you can directly use it.
Unlike Helm, it's not a templating tool, but really a config management tool.
To give you a quick example to compare both tool, Helm will use a template (like behind) and the user will define a value for each variable.
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: the-deployment
spec:
  replicas: 5
  template:
    containers:
      - name: {{ .Values.containerName }}
        image: {{ .Values.containerImage }}
```

In this example, the user can define the container name and its image. But, they can't update the number of replicas.
Once called, Helm will generate a yaml file from the template and the values given by the user.


***Kustomize will allow the user to override any configuration value. (We will see how later.)***

## Our Context

Before going further, here is the context for our next examples.

```
kubernetes/
└── application
    ├── configmap.yaml
    └── deployment.yaml
```
***deployment.yaml***

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  namespace: sandbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-deployment
  template:
    metadata:
      labels:
        app: my-deployment
    spec:
      containers:
      - name: my-container
        image: ubuntu:latest
        env:
        - name: TEST
          value: TOTO
        volumeMounts:
        - name: config-volume
          mountPath: /configs/
      volumes:
      - name: config-volume
        configMap:
          name: example-config
```

***configmap.yaml***

```
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-config
  namespace: sandbox
data:
  config.json: |
    {
      "environment" : "test"
    }
```

## How works Kustomize ?

First, Kustomize needs a ***kustomization.yaml*** file which will contain all the configurations that it needs to know.

In our example context, we will add this file in the ***/application*** folder with this content :

***kustomization.yaml***
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - configmap.yaml
```
Here, we indicate to Kustomize which files are the Kubernetes config files that we want to apply when this kustomization file is called.
This folder become our base for our next configurations.

We can verify what it would be the result of our initial customization by issuing the followin command:

```
$ kubectl kustomize kubernetes/application/
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-config
  namespace: sandbox
data:
  config.json: |
    {
      "environment" : "test"
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  namespace: sandbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-deployment
  template:
    spec:
      containers:
      - env:
        - name: TEST
          value: TOTO
        image: ubuntu:latest
        name: my-container
        volumeMounts:
        - mountPath: /configs/
          name: config-volume
      volumes:
      - configMap:
          name: example-config
        name: config-volume
```

We can deploy the deployment and config map with on of the following commands:

```
kubectl kustomize kubernetes/application | kubectl apply -f -

# Or

kubectl apply -k kubernetes/application
```

## Customization

Now that we have our base,et of YAML file, we can create our custom configurations for each environment that we maight have: prod, preprod, qa etc.

In the /kubernetes folder, we create a folder ***/environments***. Then, in this folder, we create two folders ***/dev*** and ***/prod*** (representing each environment that we have),
and we create a ***kustomization.yaml*** file in both /dev and /prod.

In both files, we add this content

***kustomization.yaml***
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../application
```

This bloc define which is the configuration basis for our customization. (In this example, it targets the previous folder that we configured)

So, if we are using the same command to view the Kustomization results, but targeting one of the environment folder, for now we will have the same output

```
$ kubectl kustomize kubernetes/environments/dev

# OR

$ kubectl kustomize kubernetes/environments/prod
apiVersion: v1
data:
  config.json: |
    {
      "environment" : "test"
    }
kind: ConfigMap
metadata:
  name: example-config
  namespace: sandbox
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  namespace: sandbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-deployment
  template:
    spec:
      containers:
      - env:
        - name: TEST
          value: TOTO
        image: ubuntu:latest
        name: my-container
        volumeMounts:
        - mountPath: /configs/
          name: config-volume
      volumes:
      - configMap:
          name: example-config
        name: config-volume
```

## Possible updates
Searching through the Kustomize documentation, you will see each and every update available, but now we will only see the principal ones.

# Patch
A **patch** in Kustomize is a file which will contains a partial configuration of a component which will override the base configuration.

For example, in production we want to increase the number of replicas and define how much resources a pod can use. So we create the two following files in the **/prod** folder.

***replica_count.yaml*** (Note: Kustomize doesn't care about the name)

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment # Name of the deployment to update
  namespace: sandbox
spec:
  replicas: 6 # The new value
```

***resources.yaml***

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment  # Name of the deployment to update
spec:
  template:
    containers:
      - name: my-container
        resources:
          requests:
            memory: "50Mi"
            cpu: "50m"
          limits:
            memory: "500Mi"
            cpu: "500m"
```

Now, to be sure that they will be used as patches, we must add a new patch code bloc in ***kubernetes/environments/prod/kustomization.yaml***
to list the two new created YAML files.

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../application

patches:
- path: replica_count.yaml
- path: resources.yaml

```
Now we can verify the results the customization for the ***prod*** environment

```
$  kubectl kustomize kubernetes/environments/prod/

apiVersion: v1
data:
  config.json: |
    {
      "environment" : "test"
    }
kind: ConfigMap
metadata:
  name: example-config
  namespace: sandbox
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  namespace: sandbox
spec:
  replicas: 6
  selector:
    matchLabels:
      app: my-deployment
  template:
    spec:
      containers:
      - env:
        - name: TEST
          value: TOTO
        image: ubuntu:latest
        name: my-container
        resources:
          limits:
            cpu: 500m
            memory: 500Mi
          requests:
            cpu: 50m
            memory: 50Mi
        volumeMounts:
        - mountPath: /configs/
          name: config-volume
      volumes:
      - configMap:
          name: example-config
        name: config-volume
```

## Patch Strategic Merge
Sometimes, we don't want to override the value of a list, but add something in the list.
In this case, we use ***patchesStrategicMergei***.

For example, if I want to add an environment variable to my container, I should
create a file with the new environment variables to add in the ***/prod*** folder

***env.yaml***

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  namespace: sandbox
spec:
  template:
    spec:
      containers:
        - name: my-container
          env:
          - name: ENVIRONMENT
            value: Production
```

and then add the ***patchesStrategicMerge*** block in the ***prod/kustomization.yaml*** file

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../application

patchesStrategicMerge:
  - env.yaml

patches:
- path: replica_count.yaml
- path: resources.yaml
```

The result of this can be verified by running the kustomization:

```
$  kubectl kustomize kubernetes/environments/prod
apiVersion: v1
data:
  config.json: |
    {
      "environment" : "test"
    }
kind: ConfigMap
metadata:
  name: example-config
  namespace: sandbox
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  namespace: sandbox
spec:
  replicas: 6
  selector:
    matchLabels:
      app: my-deployment
  template:
    metadata:
      labels:
        app: my-deployment
    spec:
      containers:
      - env:
        - name: ENVIRONMENT
          value: Production
        - name: TEST
          value: TOTO
        image: ubuntu:latest
        name: my-container
        resources:
          limits:
            cpu: 500m
            memory: 500Mi
          requests:
            cpu: 50m
            memory: 50Mi
        volumeMounts:
        - mountPath: /configs/
          name: config-volume
      volumes:
      - configMap:
          name: example-config
        name: config-volume
```
The new environment variables for the container contains both the varaiables:
+ ***ENVIRONMENT*** set to the value ***Production***
+ ***TEST*** set to the value ***TOTO***

## Generators

In Kustomize, some parameters exist to generate configmaps and secrets.
Both are similar, so we will do the example with the ***configMapGenerator***.
```
configMapGenerator:
- name: example-config
  namespace: sandbox
  # behavior: replace
  files:
    - configs/config.json
```
In this code that we can found in the kustomization.yaml file, a configmap named "example-config" will be created in the example* namespace with the content of **configs/config.json as value.  
In the commented line, we can see the parameter behavior which allows us to replace an existing configmap instead of creating a new one.


## Images

The kustomization.yaml file may also be used to do some images customization.

```
images:
- name: hello-world 
  newTag: linux
  newName: ubuntu 

```

In this example, we see 3 parameters:

+ name - To find all the images matching this name where the override will occur
+ newTag - The new tag of the image to use
+ newName - The new name of the image to use
