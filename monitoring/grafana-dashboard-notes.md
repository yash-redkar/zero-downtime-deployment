# =============================================================================
# StreamShield — Grafana Dashboard Notes (Phase 4)
# =============================================================================
#
# This file describes the recommended Grafana dashboard panels
# for monitoring the StreamShield streaming platform and release simulator.
#
# Access Grafana:
#   kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
#   Open: http://localhost:3000
#
# To create a new dashboard:
#   Grafana → Dashboards → New → Add Visualization
# =============================================================================

## Dashboard: StreamShield Release Health Monitor

Create a dashboard named: **StreamShield Release Health Monitor**

---

### Panel 1 — Request Rate (Requests per Second)

**Title:** Request Rate by Version

**Visualization:** Time series graph

**PromQL Query:**
```promql
rate(streamshield_http_requests_total[1m])
```

**Legend:** `{{version}} - {{endpoint}} - {{status}}`

**Purpose:**
Shows how many requests per second each version (v1/v2) is handling.
During unsafe rollout, all requests go to v2. During smart rollout, ~90% go to v1.

---

### Panel 2 — Error Rate (%)

**Title:** Error Rate by Version

**Visualization:** Gauge or Time series

**PromQL Query:**
```promql
100 * (
  rate(streamshield_http_requests_total{status="500"}[2m])
  /
  rate(streamshield_http_requests_total[2m])
)
```

**Thresholds:**
- Green: 0–5%
- Yellow: 5–10%
- Red: > 10%

**Purpose:**
The core alert metric. When chaos mode is ON, error rate spikes.
If this goes above 5%, the health score triggers rollback.

---

### Panel 3 — Average Latency (ms)

**Title:** Average Response Latency

**Visualization:** Time series graph

**PromQL Query:**
```promql
1000 * (
  rate(streamshield_request_latency_seconds_sum[1m])
  /
  rate(streamshield_request_latency_seconds_count[1m])
)
```

**Thresholds:**
- Green: 0–500ms
- Yellow: 500–800ms
- Red: > 800ms

**Purpose:**
High latency = buffering for streaming viewers. A latency spike > 800ms
triggers a health score deduction of 20 points.

---

### Panel 4 — Playback Failures (Total Count)

**Title:** Playback Failure Count

**Visualization:** Stat or Time series

**PromQL Query:**
```promql
increase(streamshield_playback_failures_total[5m])
```

**Legend:** `{{version}}`

**Purpose:**
Directly tracks how many streaming playback failures occurred.
A high playback failure rate in v2 with chaos mode ON proves the unsafe rollout danger.

---

### Panel 5 — Blue vs Green Pod Health

**Title:** Pod Readiness — Blue vs Green

**Visualization:** Table or Stat

**Source:** Kube-state-metrics (included in kube-prometheus-stack)

**PromQL Query — Ready pods per deployment:**
```promql
kube_deployment_status_replicas_ready{
  namespace="streamshield",
  deployment=~"streamshield-blue|streamshield-green"
}
```

**Purpose:**
Shows whether both environments are healthy at the pod level.
During a bad release, green pods may show 0/2 ready if probes fail.

---

### Panel 6 — Health Score (Simulated Gauge)

**Title:** Release Health Score

**Visualization:** Gauge (0–100)

> For the capstone, the health score is calculated by `scripts/health-score.ps1`.
> In Grafana, display error rate and latency panels as proxies for the health score.

**Approximate Health Score via PromQL (for reference):**
```promql
# Error rate contribution (lower is better)
100 - (
  clamp_max(
    rate(streamshield_http_requests_total{status="500", version="v2"}[2m])
    / clamp_min(rate(streamshield_http_requests_total{version="v2"}[2m]), 0.001)
    * 100, 100
  )
)
```

**Thresholds:**
- Green:  90–100 (Excellent)
- Yellow: 60–89  (Risky)
- Red:    0–59   (Rollback Required)

---

### Panel 7 — Chaos Mode Status

**Title:** Chaos Mode Active

**Visualization:** Stat (On/Off indicator)

**PromQL Query:**
```promql
streamshield_chaos_mode
```

**Value mappings:**
- `1` → "ON 💀" (Red)
- `0` → "OFF ✅" (Green)

**Purpose:**
Instantly shows whether the bad release simulation is active.
When chaos goes ON and error rate spikes, the dashboard tells the full story.

---

### Panel 8 — Rollback Status (Text Panel)

**Title:** Rollback Status

**Visualization:** Text (Markdown)

**Content (update manually during demo):**
```
## Current Status

| Metric | Value |
|---|---|
| Active Version | v1 (Blue) |
| Canary Traffic | 10% → v2 |
| Chaos Mode | OFF |
| Last Rollback | N/A |
| Health Score | 96/100 |
```

---

## Capstone Demo Dashboard Setup

For a quick demo setup without complex PromQL:

1. Import the **Kubernetes Cluster Overview** dashboard (ID: 7249) from Grafana.com
2. Import the **Node Exporter Full** dashboard (ID: 1860)
3. Create a custom **StreamShield** dashboard with panels 1–4 above

This gives you a professional-looking monitoring setup in under 10 minutes.
