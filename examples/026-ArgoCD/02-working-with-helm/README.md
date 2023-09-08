# Working With Helm
## HELM
***REF***: [https://kubebyexample.com/learning-paths/argo-cd/argo-cd-working-helm]

Helm is considered the defacto package manager for Kubernetes applications.  
You can define, install, and update your pre-packaged applications or comsume a prebuilt packed application from a trusted repository.  
This is a way to bundle up, and deliver prebuilt Kubernetes applications.

see [017-Helm](../../017-Helm)

The main components of Helm are:

* Chart - Which is a package consisting of related Kubernetes YAML files used to deploy something (Application/Application Stack/etc).
* Repository - Is a place where Charts can be stored, shared and distributed.
* Release - Is a specific instance of a Chart deployed on a Kubernetes cluster.

Helm works by the user providing parameters (most of the time via a YAML file **values.yaml**) against a Helm chart via the CLI.
These parameters get injected into the Helm template YAML to produce a consumable YAML that us deployed to the Kubernetes cluster.

![Helm](../../../doc/argocdHelm1.JPG)

## ArgoCD and Helm
Argo CD has native support for Helm built in.  
You can directly call a Helm chart repo and provide the values directly in the Application manifest.  
Also, you can interact and manage Helm on your cluster directly with the Argo CD UI or the argocd CLI. 

Here we are going to deploy quarkus appliaction from *redhat-developer.github.io/redhat-helm-charts* helm char repository.
We use here an ArgoCD *Customer Resource* ***quarkus-app.yaml***.

```
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: quarkus-app
  namespace: argocd
spec:
  destination:
    namespace: demo
    server: https://kubernetes.default.svc
  project: default
  source:
    helm:
      parameters:
        - name: build.enabled
          value: "false"
        - name: deploy.route.enabled
          value: "false"
        - name: image.name
          value: quay.io/redhatworkshops/gitops-helm-quarkus
    chart: quarkus
    repoURL: https://redhat-developer.github.io/redhat-helm-charts
    targetRevision: 0.0.3
  syncPolicy:
    retry:
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m0s
      limit: 5
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

+ ***parameters***: This section is where you'll enter the parameters you want to pass to the Helm chart. These are the same values that you'd have in your Values.yaml file.
+ ***chart***: This is the name of the chart you want to deploy from the Helm Repository.
+ ***repoURL***:  This is the URL of the Helm Repository.
+ ***targetRevision***: This is the version of the chart you want to deploy.


