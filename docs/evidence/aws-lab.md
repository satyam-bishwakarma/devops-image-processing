# AWS lab evidence

The lab runs one Jenkins automation host, one K3s server, and one K3s worker in a shared VPC in Sydney (`ap-southeast-2`). The instances use AWS Systems Manager for administration. The K3s nodes were both Ready on `v1.35.10+k3s1` during verification.

| Check | Verified result |
| --- | --- |
| Jenkins and Docker | Jenkins build #4 checked out [`aa7b811`](https://github.com/satyam-bishwakarma/devops-image-processing/commit/aa7b8117cb5cd35fd3fde081b98467c8628726c6), passed its smoke checks, and published the green image to GHCR. |
| Kubernetes deployment | Blue and green were both ready. The active Service served build `e9c9faf` and the preview Service served `aa7b811` before promotion. |
| CPU autoscaling | Four workers sent 1200 × 1200 PNG conversions for 125 seconds. The active Deployment scaled from 1 to 4 replicas and returned to 1 after cooldown. The load run completed 597 conversions without an observed failure. |
| Monitoring | Prometheus scraped both colours. Grafana's **Image Processing Lab** dashboard used the healthy Prometheus datasource and displayed panels for conversion rate, p95 processing time, and HPA replicas. Monitoring was verified separately from the recorded scaling run. |
| Blue/green promotion and rollback | The active Service went blue → green → blue under traffic. The probe completed 101 conversions without an observed failure and sampled both build versions. |

The reproducible starting digests are in [the deployment overlay](../../deploy/kustomization.yaml). Use the [demo runbook](../runbooks/next-milestones.md) to repeat the checks and capture the final review recordings.
