# Implementation and review checklist

1. Run the shared baseline locally. Open the page, upload a JPEG or WebP, preview the PNG, and download it. Use the smoke script to check valid and rejected uploads.
2. Give each feature its own PR. Resize/crop, grayscale/blur, and rotate/format conversion each include UI, API, and validation changes. Review and test a teammate's PR before merging it.
3. Confirm AWS project access, region, credits, and budget. Draft and review Terraform for the VPC and EC2 instances, then use Ansible to configure K3s and Jenkins. Record the first and second playbook runs.
4. Configure the Jenkins Docker agent and run its build and smoke pipeline. Add registry publishing and namespace-scoped deployment as separate stages once credentials and targets are available.
5. Deploy both colours using real image digests. The base manifest uses a local placeholder image. For private images configure a pull credential. Keep the active and preview Services private until routing and access are agreed. When updating images, preserve the active selector and avoid reapplying the initial selector defaults after promotion.
6. Install Prometheus and Grafana and configure scraping of the application metrics. Confirm Metrics Server supplies CPU metrics to HPA. Generate real image-processing traffic, record replica changes and response metrics, then add Prometheus Adapter for custom-metric scaling.
7. Check readiness and run smoke tests against preview. Switch the active Service to the tested colour under continuous load. Keep the previous colour running, measure failures, and practise switching back.
8. Record module evidence with commits, release identifiers, dashboard timestamps, and each teammate's actual contribution.

The application baseline and build/smoke pipeline are the initial implementation. AWS provisioning, cluster bootstrap, monitoring installation, publishing, and release promotion still require implementation and verification.
