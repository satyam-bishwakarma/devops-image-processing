# Install and verify monitoring

Run from the repository root with `kubectl` configured for the K3s cluster. The app namespace and Deployments should already exist.

```sh
kubectl apply -f monitoring/prometheus/stack.yaml
for attempt in $(seq 1 60); do
  kubectl -n kube-system get job helm-install-image-processing-monitoring >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n kube-system wait --for=condition=complete job/helm-install-image-processing-monitoring --timeout=480s
kubectl wait --for=condition=Established crd/podmonitors.monitoring.coreos.com --timeout=120s
kubectl -n image-processing apply -f monitoring/prometheus/podmonitor.yaml
kubectl apply -k monitoring/grafana
kubectl -n image-monitoring rollout status deployment/image-processing-monitoring-grafana --timeout=180s
kubectl -n image-monitoring rollout status statefulset/prometheus-image-monitoring-prometheus --timeout=180s
```

K3s installs the pinned `kube-prometheus-stack` chart. The PodMonitor selects both application colours and adds the pod's `color` label to each series. Grafana loads the **Image Processing Lab** dashboard from the ConfigMap. Prometheus stores up to one day or 400 MB of samples in this lab setup.

On the Prometheus Targets page, look for two or more `image-processing` targets and confirm both colours are up. In Grafana, confirm conversion rate, p95 processing time, and current replica counts. Generate conversions first so the app exposes the success series and has latency observations. CPU HPA reads from Metrics Server, and kube-state-metrics exports the resulting replica counts for Grafana.

Use the [demo runbook](../../docs/runbooks/next-milestones.md) to access the private Grafana and Prometheus Services.
