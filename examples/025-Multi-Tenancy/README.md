# Multi-Tenancy
***REF***: [https://kubernetes.io/docs/concepts/security/multi-tenancy/]
			
This page provides an overview of available configuration options and best practices for cluster multi-tenancy.

Sharing clusters saves costs and simplifies administration. However, sharing clusters also presents challenges such as security, fairness, and managing noisy neighbors.
Clusters can be shared in many ways. In some cases, different applications may run in the same cluster.  
In other cases, multiple instances of the same application may run in the same cluster, one for each end user.  
All these types of sharing are frequently described using the umbrella term multi-tenancy.

## Tenants 
When discussing multi-tenancy in Kubernetes, there is no single definition for a "tenant". Rather, the definition of a tenant will vary depending on whether multi-team or multi-customer tenancy is being discussed.

In **multi-team** usage, a tenant is typically a team, where each team typically deploys a small number of workloads that scales with the complexity of the service. 
However, the definition of "team" may itself be fuzzy, as teams may be organized into higher-level divisions or subdivided into smaller teams.
  
By contrast, if each team deploys dedicated workloads for each new client, they are using a **multi-customer** model of tenancy. In this case, a "tenant" is simply a group of users who share a single workload.   
This may be as large as an entire company, or as small as a single team at that company.

In many cases, the same organization may use both definitions of "tenants" in different contexts. 

Hybrid architectures are also possible, such as a SaaS provider using a combination of per-customer workloads for sensitive data, combined with multi-tenant shared services.

## Isolation

There are several ways to design and build multi-tenant solutions with Kubernetes. Each of these methods comes with its own set of tradeoffs that impact the isolation level, implementation effort, operational complexity, and cost of service.

A Kubernetes cluster consists of a **control plane** which runs Kubernetes software, and a **data plane** consisting of worker nodes where tenant workloads are executed as pods.  
Tenant isolation can be applied in both the control plane and the data plane based on organizational requirements.

The level of isolation offered is sometimes described using terms like **“hard” multi-tenancy**, which implies strong isolation, and **“soft” multi-tenancy**, which implies weaker isolation.  
In many extreme cases, it may be easier or necessary to forgo any cluster-level sharing at all and assign each tenant their dedicated cluster. 
The benefit of stronger tenant isolation must be evaluated against the cost and complexity of managing multiple clusters.

Here we focus on isolation techniques used for shared Kubernetes clusters. For multicluster use case see https://github.com/kubernetes/community/blob/master/sig-multicluster/README.md

## Control plane isolation
Control plane isolation ensures that different tenants cannot access or affect each others' Kubernetes API resources.

### Namespaces 

In Kubernetes, a Namespace provides a mechanism for isolating groups of API resources within a single cluster. This isolation has two key dimensions:

+ Object names within a namespace can overlap with names in other namespaces, similar to files in folders. This allows tenants to name their resources without having to consider what other tenants are doing.
+ Many Kubernetes security policies are scoped to namespaces. For example, RBAC Roles and Network Policies are namespace-scoped resources. Using RBAC, Users and Service Accounts can be restricted to a namespace.

In a multi-tenant environment, a Namespace helps segment a tenant's workload into a logical and distinct management unit. In fact, a common practice is to isolate every workload in its own namespace, even if multiple workloads are operated by the same tenant. 
This ensures that each workload has its own identity and can be configured with an appropriate security policy.

The namespace isolation model requires configuration of several other Kubernetes resources, networking plugins, and adherence to security best practices to properly isolate tenant workloads. These considerations are discussed below.

### Access controls
The most important type of isolation for the control plane is authorization. If teams or their workloads can access or modify each others' API resources, they can change or disable all other types of policies thereby negating any protection those policies may offer. 
As a result, it is critical to ensure that *each tenant has the appropriate access to only the namespaces they need, and no more.* This is known as the ***"Principle of Least Privilege."***

Role-based access control (**RBAC**) is commonly used to enforce authorization in the Kubernetes control plane, for both users and workloads (service accounts).  
*Roles* and *RoleBindings* are Kubernetes objects that are used at a namespace level to enforce access control in your application;  
similar objects exist for authorizing access to cluster-level objects, though these are less useful for multi-tenant clusters.

### Quotas
Kubernetes workloads consume node resources, like CPU and memory. In a multi-tenant environment, you can use Resource Quotas to manage resource usage of tenant workloads. 
Resource quotas are namespaced objects. By mapping tenants to namespaces, cluster admins can use quotas to ensure that a tenant cannot monopolize a cluster's resources or overwhelm its control plane. Namespace management tools simplify the administration of quotas.   
In addition, while Kubernetes quotas only apply within a single namespace, some namespace management tools allow groups of namespaces to share quotas, giving administrators far more flexibility with less effort than built-in quotas.
+ Quotas prevent a single tenant from consuming greater than their allocated share of resources hence minimizing the “noisy neighbor” issue, where one tenant negatively impacts the performance of other tenants' workloads.
+ Quotas cannot protect against all kinds of resource sharing, such as network traffic. Node isolation (described below) may be a better solution for this problem.

## Data Plane Isolation
Data plane isolation ensures that pods and workloads for different tenants are sufficiently isolated.

### Network isolation
By default, all pods in a Kubernetes cluster are allowed to communicate with each other, and all network traffic is unencrypted.

Pod-to-pod communication can be controlled using Network Policies, which restrict communication between pods using namespace labels or IP address ranges.
In a multi-tenant environment where strict network isolation between tenants is required, starting with a default policy that denies communication between pods is recommended with another rule that allows all pods to query the DNS server for name resolution.

With such a default policy in place, you can begin adding more permissive rules that allow for communication within a namespace.  
It is also recommended not to use empty label selector **'{}'** for **namespaceSelector** field in network policy definition, in case traffic need to be allowed between namespaces.

***Warning: Network policies require a CNI plugin that supports the implementation of network policies. Otherwise, NetworkPolicy resources will be ignored.***

More advanced network isolation may be provided by service meshes, which provide OSI Layer 7 policies based on workload identity, in addition to namespaces. They frequently also offer encryption using mutual TLS, protecting your data even in the presence of a compromised node, and work across dedicated or virtual clusters. However, they can be significantly more complex to manage and may not be appropriate for all users

### Sandboxing containers

Kubernetes pods are composed of one or more containers that execute on worker nodes. Containers utilize OS-level virtualization and hence offer a weaker isolation boundary than virtual machines that utilize hardware-based virtualization.
In a shared environment, unpatched vulnerabilities in the application and system layers can be exploited by attackers for container breakouts and remote code execution that allow access to host resources.
Sandboxing provides a way to isolate workloads running in a shared cluster. It typically involves running each pod in a separate execution environment such as a virtual machine or a userspace kernel. Sandboxing is often recommended when you are running untrusted code, where workloads are assumed to be malicious.

gVisor is one option beside Kata Containers or Firecracker for sandboxing containers to minimize the risk when running untrusted workloads on Kubernetes.

### Node Isolation 
Node isolation is another technique that you can use to isolate tenant workloads from each other.  
With node isolation, a set of nodes is dedicated to running pods from a particular tenant and co-mingling of tenant pods is prohibited.  
This configuration reduces the noisy tenant issue, as all pods running on a node will belong to a single tenant. The risk of information disclosure is slightly lower with node isolation because an attacker that manages to escape from a container will only have access to the containers and volumes mounted to that node.
Although workloads from different tenants are running on different nodes, it is important to be aware that the kubelet and (unless using virtual control planes) the API service are still shared services.
Node isolation can be implemented using an pod node selectors or a Virtual Kubelet.


## Additional Considerations
### API Priority and Fairnes
API priority and fairness is a Kubernetes feature that allows you to assign a priority to certain pods running within the cluster.  
When an application calls the Kubernetes API, the API server evaluates the priority assigned to pod. 
Calls from pods with higher priority are fulfilled before those with a lower priority. When contention is high, lower priority calls can be queued until the server is less busy or you can reject the requests.
Using API priority and fairness will not be very common in SaaS environments unless you are allowing customers to run applications that interface with the Kubernetes API, for example, a controller.

### Quality-of-Service (QoS)
When you’re running a SaaS application, you may want the ability to offer different Quality-of-Service (QoS) tiers of service to different tenants. 
There are several Kubernetes constructs that can help you accomplish this within a shared cluster, including network QoS, storage classes, and pod priority and preemption. The idea with each of these is to provide tenants with the quality of service that they paid for.

+ Typically, all pods on a node share a network interface. Without network QoS, some pods may consume an unfair share of the available bandwidth at the expense of other pods. 
The Kubernetes bandwidth plugin creates an extended resource for networking that allows you to use Kubernetes resources constructs i.e. requests/limits, to apply rate limits to pods by using Linux tc queues.

+ For storage QoS, you will likely want to create different storage classes or profiles with different performance characteristics. 

+ With POD priority and preemption where you can assign priority values to pods. When scheduling pods, the scheduler will try evicting pods with lower priority when there are insufficient resources to schedule pods that are assigned a higher priority. If you have a use case where tenants have different service tiers in a shared cluster e.g. free and paid, you may want to give higher priority to certain tiers using this feature.

### DNS
Kubernetes clusters include a Domain Name System (DNS) service to provide translations from names to IP addresses, for all Services and Pods. By default, the Kubernetes DNS service allows lookups across all namespaces in the cluster.
In multi-tenant environments where tenants can access pods and other Kubernetes resources, or where stronger isolation is required, it may be necessary to prevent pods from looking up services in other Namespaces.
You can restrict cross-namespace DNS lookups by configuring security rules for the DNS service. 
For example, CoreDNS (the default DNS service for Kubernetes) can leverage Kubernetes metadata to restrict queries to Pods and Services within a namespace.

When a **Virtual Control Plane** per tenant model is used, a DNS service must be configured per tenant or a multi-tenant DNS service must be used. Here is an example of a customized version of CoreDNS that supports multiple tenants.

### Operators
Operators are Kubernetes controllers that manage applications. Operators can simplify the management of multiple instances of an application, like a database service, which makes them a common building block in the multi-consumer (SaaS) multi-tenancy use case.


## Implementation

There are two primary ways to share a Kubernetes cluster for multi-tenancy: using **Namespaces** (that is, a Namespace per tenant) or by **virtualizing the control plane** (that is, virtual control plane per tenant).

### Namespaces
Namespace isolation is well-supported by Kubernetes, has a negligible resource cost, and provides mechanisms to allow tenants to interact appropriately, such as by allowing service-to-service communication. However, it can be difficult to configure, and doesn't apply to Kubernetes resources that can't be namespaced, such as Custom Resource Definitions, Storage Classes, and Webhooks.  What if for example, an organization may have divisions, teams, and subteams - which should be assigned a namespace?  Kubernetes provides the ***Hierarchical Namespace Controller*** (***HNC***), which allows you to organize your namespaces into hierarchies, and share certain policies and resources between them. 

### Control plane virtualization
allows for isolation of non-namespaced resources at the cost of somewhat higher resource usage and more difficult cross-tenant sharing. It is a good option when namespace isolation is insufficient but dedicated clusters are undesirable, due to the high cost of maintaining them (especially on-prem) or due to their higher overhead and lack of resource sharing. However, even within a virtualized control plane, you will likely see benefits by using namespaces as well.

The virtual control plane based multi-tenancy model extends namespace-based multi-tenancy by providing each tenant with dedicated control plane components, and hence complete control over cluster-wide resources and add-on services. Worker nodes are shared across all tenants, and are managed by a Kubernetes cluster that is normally inaccessible to tenants. This cluster is often referred to as a super-cluster (or sometimes as a host-cluster). Since a tenant’s control-plane is not directly associated with underlying compute resources it is referred to as a virtual control plane.

A virtual control plane typically consists of the Kubernetes API server, the controller manager, and the etcd data store. It interacts with the super cluster via a metadata synchronization controller which coordinates changes across tenant control planes and the control plane of the super-cluster.

By using per-tenant dedicated control planes, most of the isolation problems due to sharing one API server among all tenants are solved.

The improved isolation comes at the cost of running and maintaining an individual virtual control plane per tenant. In addition, per-tenant control planes do not solve isolation problems in the data plane, such as node-level noisy neighbors or security threats. These must still be addressed separately.
