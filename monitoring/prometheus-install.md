# =============================================================================
# StreamShield — Prometheus Installation Guide (Phase 4)
# =============================================================================
#
# This guide installs the full Prometheus + Grafana monitoring stack
# into your Minikube cluster using Helm.
#
# After installation:
#   - Prometheus scrapes /metrics from both v1 and v2 pods
#   - Grafana visualizes all metrics on dashboards
#   - Alerts can be configured based on health score thresholds
#
# Prerequisites: Helm must be installed.
#   winget install Helm.Helm
#   OR download from: https://helm.sh/docs/intro/install/
#
# Verify Helm is installed:
#   helm version
# =============================================================================

## Step 1 — Add the Prometheus Helm Repository

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Expected output:
```
"prometheus-community" has been added to your repositories
Update Complete. Happy Helming!
```

---

## Step 2 — Install the Kube-Prometheus Stack

This installs Prometheus, Alertmanager, and Grafana together.

```powershell
helm install monitoring prometheus-community/kube-prometheus-stack `
    -n monitoring --create-namespace
```

> This may take 2–4 minutes on first run as it pulls several images.

---

## Step 3 — Verify All Monitoring Pods are Running

```powershell
kubectl get pods -n monitoring
```

Expected output (all pods should show `Running`):
```
NAME                                                   READY   STATUS    AGE
alertmanager-monitoring-kube-prometheus-alertmanager   2/2     Running   2m
monitoring-grafana-xxxxxxxxxx-xxxxx                    3/3     Running   2m
monitoring-kube-prometheus-operator-xxxxxxxxxx-xxxxx   1/1     Running   2m
monitoring-kube-state-metrics-xxxxxxxxxx-xxxxx         1/1     Running   2m
monitoring-prometheus-node-exporter-xxxxx              1/1     Running   2m
prometheus-monitoring-kube-prometheus-prometheus        2/2     Running   2m
```

---

## Step 4 — Open Grafana in Browser

Port-forward the Grafana service to your localhost:

```powershell
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

Open in browser: **http://localhost:3000**

> Keep this terminal window open. Press `Ctrl+C` to stop port-forwarding.

---

## Step 5 — Get Grafana Login Password

**Username:** `admin`

**Password:** Retrieve it with this command:

```powershell
kubectl get secret monitoring-grafana -n monitoring `
    -o jsonpath="{.data.admin-password}"
```

This returns a **Base64-encoded** password. Decode it with:

```powershell
# Decode Base64 password in PowerShell
$encoded = kubectl get secret monitoring-grafana -n monitoring `
               -o jsonpath="{.data.admin-password}"
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))
Write-Host "Grafana Password: $decoded"
```

---

## Step 6 — Configure Prometheus to Scrape StreamShield

Create a ServiceMonitor so Prometheus auto-discovers the StreamShield `/metrics` endpoints.

> For the capstone demo, you can also manually add a scrape target in Prometheus.

Open Prometheus UI:

```powershell
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring
```

Open: **http://localhost:9090**

Go to **Status → Targets** to see all scraped services.

---

## Step 7 — Useful Prometheus Queries (PromQL)

Once inside Prometheus, try these queries in the **Graph** tab:

```promql
# Total HTTP requests to StreamShield (grouped by version and status)
rate(streamshield_http_requests_total[1m])

# Error rate for v2
rate(streamshield_http_requests_total{version="v2", status="500"}[1m])
  /
rate(streamshield_http_requests_total{version="v2"}[1m])

# Average request latency for v2 /watch endpoint
rate(streamshield_request_latency_seconds_sum{version="v2", endpoint="/watch"}[1m])
  /
rate(streamshield_request_latency_seconds_count{version="v2", endpoint="/watch"}[1m])

# Total playback failures
increase(streamshield_playback_failures_total[5m])

# Chaos mode status (1 = ON, 0 = OFF)
streamshield_chaos_mode
```

---

## Step 8 — Cleanup (Optional)

To remove the monitoring stack:

```powershell
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```

---

## Capstone Note

For the demo, Prometheus + Grafana provide **supporting visibility**.
The **primary health score calculation** is done by `scripts/health-score.ps1`
which runs probes and calculates score in real-time.

Grafana is shown to demonstrate professional-grade observability on top of the core simulator.
