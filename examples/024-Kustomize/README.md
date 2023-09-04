**01-Example**: A very basic example to customize the base yaml files with  using **commonLables** kustomize feature to add labels and selectores to base YAML files
**02-Example**: In this example we create two different customization for *dev* and *prod* environment using kustomization **patches** and **patchesStrategicMerge** to customize our base deployment set of YAML files.
**03-Example**: Like 02-Example but some more complex customization
**04-Example**: Use Helm and Kustomize toghether. We use kustomize to customize helm charts for deployment on dev an prod environment. We simply change the namespace property value and the number of replicas for each environment.
