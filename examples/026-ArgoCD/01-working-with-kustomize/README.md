# Argo CD Working With Kustomize
***REF***: [https://kubebyexample.com/learning-paths/argo-cd/argo-cd-working-kustomize]
Kustomize is a tool that traverses a Kubernetes manifest to add, remove or update configuration options without forking. 

It achieves this with a series of ***bases*** (where the YAML is stored) and ***overlays*** (directores where deltas are stored). See: [024-Kustomize](../../024-Kustomize/README.md)  
Argo CD has native built in support for Kustomize and will automatically detect the use of Kustomize without further configuration.

## Kustomized Repository
The repository we are going to use has the following directory structure and files. We have a base deployment reference set of manifest files insed *base* directory, and a on overly kustomization in *overly* direcotry:

```
├── README.md
├── base
│   ├── kustomization.yaml
│   ├── test-deployment.yaml
│   ├── test-ns.yaml
│   └── test-svc.yaml
└── overlays
    └── dev
        └── kustomization.yaml
    └── production
        └── kustomization.yaml
```
The *kustomization.yaml* file inside *base* directory simply list all resources files that can take part to the customization.

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- test-deployment.yaml
- test-ns.yaml
- test-svc.yaml
```

Inside *overlay/dev* the *kustomization.yaml*  file we instruct how to patch the base deployment. It firs declare where to finde the *base* customizaton and then describe what and how to patch it for a *dev* environment deployment.
***patchesJson6902*** instruct how to patch and it requires a selector to identify what to patch. In this case the selecteor is the **deployment** named **welcome-php**. In a development environment we set the *replica count* from 1 to 3

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

patchesJson6902:
  - target:
      version: v1
      kind: Deployment
      name: welcome-php
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
```
We do the same for the production environment by setting the *replicas count* to 10.

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

patchesJson6902:
  - target:
      version: v1
      kind: Deployment
      name: welcome-php
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
```

## Deployment
### Base Deployment
Here we use argocd client to deploy the application with the base customization.

```
argocd app create kapp \
--repo https://github.com/cgiacomini/vagrant--kubernetes \
--path examples/026-ArgoCD/01-working-with-kustomize/base \
--dest-namespace kapp \
--dest-server https://kubernetes.default.svc \
--self-heal \
--sync-policy automated \
--sync-retry-limit 5 \
--revision main
```

