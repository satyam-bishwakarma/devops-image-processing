# Run the DevOps lab demo

Use the shared AWS lab in `ap-southeast-2`. Start its three EC2 instances and wait for them to register with Systems Manager. Get the automation host and K3s server IDs from Terraform's `hosts` output. Run commands that use repository files from a checkout or working copy. For the Kubernetes steps, use a shell where `kubectl get nodes` succeeds against the lab cluster. From an interactive SSM shell on the K3s server, use `sudo -i` if your account needs root access to the K3s kubeconfig.

## Build and publish

Forward the Jenkins automation host's loopback port 8080 using the `AWS-StartPortForwardingSession` Session Manager document. Open [Jenkins](http://127.0.0.1:8080/job/image-processing/) and run the job against `main`. Show the Docker agent, smoke stage, and successful publish. Copy the digest reference from the archived `image-reference.txt`.

## Set up the Kubernetes demo

For a fresh lab, create the namespace and provision the `ghcr-pull` image-pull Secret with a read-only GHCR credential in that namespace before applying the manifests.

```sh
kubectl create namespace image-processing --dry-run=client -o yaml | kubectl apply -f -
kubectl -n image-processing get secret ghcr-pull
kubectl apply -k deploy
kubectl -n image-processing rollout status deployment/image-processing-blue --timeout=180s
kubectl -n image-processing rollout status deployment/image-processing-green --timeout=180s
```

The committed demo pins both tested builds and starts with blue active and green in preview. Apply the full overlay only for initial setup or an intentional demo reset because it declares the starting Service selectors. For a running lab, update the idle Deployment explicitly and preserve the active selector. Follow the [monitoring installation](../../monitoring/prometheus/README.md) to set up the dashboard.

## Reach the Services privately

From the K3s server, run `kubectl -n image-processing get svc` to find the active and preview ClusterIPs. Run `kubectl -n image-monitoring get svc` for Grafana and Prometheus. From Windows PowerShell, start one tunnel per Service, using its ClusterIP and service port. For example, forward the Grafana Service on port 80 to local port 3000.

```powershell
$serverId = '<K3s server EC2 instance ID>'
$serviceIp = '<Grafana ClusterIP>'
aws ssm start-session --region ap-southeast-2 --target $serverId --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters "host=$serviceIp,portNumber=80,localPortNumber=3000"
```

Use local ports 8000 for active and 8001 for preview, with remote port 80 for each. Prometheus uses remote port 9090. Open [the Grafana dashboard](http://127.0.0.1:3000/d/image-processing-lab/image-processing-lab) with the lab's Grafana credentials. A tunnel to the ClusterIP follows changes to the Service during promotion and distributes new connections to its ready pods.

## Record CPU autoscaling

Keep Grafana's replica panel and `kubectl -n image-processing get hpa --watch` visible. From a terminal with Python 3.9 or newer and the active Service tunnel open, run:

```sh
python scripts/load.py http://127.0.0.1:8000 --seconds 125 --workers 4
```

Record the replica increase, the request result, and the later return to one replica. Keep the dashboard open during cooldown, which can take several minutes. [Lab evidence](../evidence/aws-lab.md) records a run that reached four replicas.

## Record promotion and rollback

Confirm that blue is active and green is idle before using the following commands. If green already serves the candidate digest, skip the image update.

```sh
kubectl -n image-processing get svc image-processing-active image-processing-preview -o custom-columns=NAME:.metadata.name,COLOR:.spec.selector.color
kubectl -n image-processing set image deployment/image-processing-green app='<image digest reference from Jenkins>'
kubectl -n image-processing rollout status deployment/image-processing-green --timeout=180s
```

Check `/api/version` on both tunnel URLs and exercise a real conversion on preview. With the README's Python environment on Windows, set `$env:SMOKE_URL = 'http://127.0.0.1:8001'` and run `.\.venv\Scripts\python.exe scripts/smoke.py` to verify preview.

In another terminal, run `python scripts/load.py http://127.0.0.1:8000 --seconds 45 --workers 1`. From a shell with an authenticated `kubectl` context, switch the active Service and confirm that `/api/version` on port 8000 returns the green build. Then roll back during the same traffic run and confirm the blue version returns.

```sh
python3 scripts/release/promote.py --context "$(kubectl config current-context)" --namespace image-processing --color green
python3 scripts/release/promote.py --context "$(kubectl config current-context)" --namespace image-processing --color blue
```

Save the traffic result and both version changes. The rollback uses the prior ready Deployment. Stop the lab instances after recording if the team is finished with the environment.
