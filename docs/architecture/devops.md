# Development and deployment architecture

```mermaid
flowchart LR
    Dev[Three contributors] --> Git[GitHub issues and pull requests]
    Git --> Jenkins[Jenkins build and smoke checks]
    Jenkins -.-> Registry[GHCR image by digest]
    Terraform[Terraform provisioning] -.-> AWS
    Ansible[Ansible host configuration] -.-> AWS
    subgraph AWS[Shared AWS VPC]
        Users[Demo users and load test] --> Ingress[Traefik ingress]
        Ingress --> Active[Active Service]
        Active -->|Selected colour| Blue[Blue Deployment]
        Active -.->|After promotion| Green[Green Deployment]
        Preview[Private preview Service] --> Green
        Metrics[Metrics Server] --> HPA[CPU HPA]
        HPA --> Blue
        HPA --> Green
        Blue --> Prometheus
        Green --> Prometheus
        Prometheus --> Grafana
    end
    Registry -.-> Blue
    Registry -.-> Green
    Jenkins -.->|Preview and approved promotion| Active
```

The current implementation provides the app, metrics endpoint, Jenkins build and smoke definition, and base Kubernetes manifest. Registry publishing, cloud provisioning, host configuration, and live traffic paths are planned. Both colour deployments are declared in the base. The initial Service selectors route active traffic to blue and preview traffic to green.
