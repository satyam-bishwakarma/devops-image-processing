# AWS lab verification

The lab was provisioned in Sydney with three Free-plan-eligible c7i-flex.large instances in one VPC. The original t3.large request was rejected by the AWS Free plan before any hosts launched.

| Check | Result | Systems Manager command |
| --- | --- | --- |
| Automation host | Docker engine reachable. Jenkins login returned success on loopback port 8080. | c2d56e62-a937-477f-b054-b7093412c811 |
| Application container | The staged app snapshot built on the automation host. HTTP smoke checks passed for conversion, invalid and oversized uploads, version and metrics. | 3d0f8ec3-a883-4021-b6b0-a4c9f35580cc |
| K3s | Control plane and worker were both Ready on v1.35.10+k3s1 using containerd. | c94a86da-f4bc-45ea-a9cf-9d57b6f8a186 |

The container check ran directly through Systems Manager. The Jenkins agent and repository job, registry publishing, application deployment, dashboards, autoscaling and traffic promotion still require live verification.

The AWS budget uses a USD 25 monthly threshold with USD 10 and USD 20 actual-cost alerts before credits. Stop the instances between sessions to limit compute charges. Their attached storage is retained.
