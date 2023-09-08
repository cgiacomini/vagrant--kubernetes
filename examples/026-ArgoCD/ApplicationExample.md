# Application Deplyment Example
Argo CD's primary job is to make sure that your desired state, stored in Git, matches your running state on your Kubernetes installation.  
It does this by comparing Kubernetes declarations (stored in YAML or JSON in Git) with the running state.  
Argo CD does this by treating a group of related manifests as an atomic unit.  
This atomic unit is called an Application, in Argo CD.  
An Argo CD Application is controlled by the Argo CD Application Controller via a Custom Resource.

## Application Repository
The application we are going to use is 


