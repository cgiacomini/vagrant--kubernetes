# Limit Ranges

By default, containers run with unbounded compute resources on a Kubernetes cluster.  
Using **resourcesQuota** a cluster operator can restrict resources consumption within a specific namespace.  
But using only resourcesQuota we may end up in a situation where a single object could monopolize all available resoureces within the namespace.  

**LimitRange** is a policy to constrain the resource allocations, limits and requests, that can be spcified for an object in a namespace, POD or PVC for example.
