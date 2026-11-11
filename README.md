# Automated DevOps Pipeline for Scalable Image Processing

Three-member DevOps course project. The shared baseline accepts JPEG, PNG, and WebP images and returns a PNG with an in-browser preview. The API exposes health, version, and Prometheus metrics endpoints.

## Run locally on Windows

Run from the repository root with Node.js and Python installed.

```powershell
npm.cmd --prefix frontend ci
npm.cmd --prefix frontend run build
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
.\.venv\Scripts\python.exe -m uvicorn backend.app:app --host 127.0.0.1 --port 8000
```

Open http://127.0.0.1:8000. In a second terminal, run `.\.venv\Scripts\python.exe scripts/smoke.py` to check the running app.

With Docker running, `docker compose up --build` builds and serves the same app at that address. Stop it with `docker compose down`.

The Jenkinsfile builds and smoke tests the image on a Linux agent labelled `docker`. The Kubernetes base contains blue and green Deployments, active and preview Services, and CPU HPAs. Supply real image digests and an environment namespace before deploying. See [implementation and review checklist](docs/runbooks/next-milestones.md) for the remaining integration work.

## Planned stack

React, FastAPI, Pillow, GitHub, AWS VPC/EC2/IAM, Terraform, Ansible, Jenkins, Docker, GHCR, K3s, Traefik, Prometheus, Grafana, HPA, and k6. Start with CPU scaling, then add Prometheus Adapter for custom metrics. Demonstrate blue-green preview, promotion, and rollback.

## Structure

- frontend/ and backend/: application source
- tests/: integration and load tests
- infra/terraform/: AWS provisioning
- infra/ansible/: machine configuration
- deploy/: Kubernetes manifests
- monitoring/: metrics and dashboard configuration
- scripts/release/: release automation
- docs/: architecture, runbooks, and review evidence

## Collaboration

Use feature branches and focused pull requests. Rotate reviews, implementation areas, and release operation. Everyone contributes to frontend, backend, tests, and operations. Preserve accurate authorship and record generated scaffolding as shared setup work.

## Credentials

Use authenticated connections and AWS profiles. Store runtime secrets in credential stores, outside this repository. Do not add passwords, access tokens, private keys, kubeconfigs, Terraform state, or credential exports. Ignore rules do not encrypt files or prevent privileged access.

## Next decisions

Team GitHub accounts: satyam-bishwakarma, Sushil905, and Pathakarnav22. Collaborator invitations were sent to both teammates. Confirm deployment region, budget, and review deadline. Access was verified locally; verification does not establish all provisioning permissions or available credits.
