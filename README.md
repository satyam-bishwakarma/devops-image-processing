# Scalable Image Processing

A DevOps course project that takes an image-processing web app through build, deployment, monitoring, autoscaling, and release rollback. The React UI accepts JPEG, PNG, and WebP. FastAPI and Pillow convert uploads to PNG, with optional resize and crop.

## Run locally

From the repository root, with Docker running:

```sh
docker compose up --build
```

Open [the image processing app](http://127.0.0.1:8000). Use `docker compose down` to stop it.

For a Windows setup with Node.js 22 and Python 3.12:

```powershell
npm.cmd --prefix frontend ci
npm.cmd --prefix frontend run build
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
.\.venv\Scripts\python.exe -m uvicorn backend.app:app --host 127.0.0.1 --port 8000
```

In a second terminal, run `.\.venv\Scripts\python.exe scripts/smoke.py` against the running app. The smoke checks cover the UI, PNG conversion, invalid and oversized inputs, build version, and metrics.

## Deployment and review

- [DevOps architecture and tool trade-offs](docs/architecture/devops.md)
- [Demo runbook](docs/runbooks/next-milestones.md) for private access, deployment, scaling, and rollback
- [Verified AWS lab results](docs/evidence/aws-lab.md) for Jenkins, K3s, autoscaling, and the blue/green test
- [AWS provisioning](infra/terraform/README.md) and [host setup](infra/ansible/README.md)
- [Prometheus and Grafana installation](monitoring/prometheus/README.md)

Jenkins builds, smoke tests, and publishes the image to GHCR from `main`. It archives the immutable image reference in `image-reference.txt`. A release operator deploys the image to the idle colour, tests it via the preview Service, and switches the active Service. Kubernetes HPA scales each colour on CPU via Metrics Server. Prometheus scrapes application metrics, and Grafana graphs them alongside HPA replica counts.

## Working together

The repository collaborators are `satyam-bishwakarma`, `Sushil905`, and `Pathakarnav22`. Use a feature branch for each change, record its verification in the PR, and request a teammate's review before merging. Use individual GitHub and AWS identities. Keep GHCR tokens, Jenkins credentials, kubeconfigs, private keys, and Terraform state outside Git.
