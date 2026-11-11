# Scrape image processing metrics

Apply the PodMonitor in the application's namespace after installing Prometheus Operator. Configure the Prometheus instance to select that namespace and this PodMonitor. The selector matches both blue and green pods by their existing application label, and the color label distinguishes their time series.

Verify that both colours appear on the Prometheus Targets page. In Grafana, use the Prometheus data source and graph the following queries.

- Throughput by colour and result — sum by (color, result) (rate(image_processing_requests_total[2m]))
- 95th-percentile processing time by colour — histogram_quantile(0.95, sum by (color, le) (rate(image_processing_duration_seconds_bucket[5m])))

Check CPU scaling independently through the Kubernetes HPA status. Save a dashboard screenshot and the corresponding HPA events for the faculty review.
