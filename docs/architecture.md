# StreamShield Simulator — System Architecture
## Phase 4 Complete Architecture Document

---

## Overview

StreamShield Simulator is a DevOps capstone project that demonstrates the difference between unsafe and safe release strategies for a high-traffic streaming platform. It uses a real Kubernetes blue-green deployment running locally on Minikube with NGINX Ingress, health score monitoring, and automated rollback.

---

## ASCII Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     STREAMSHIELD ARCHITECTURE                       │
│                    (Local Minikube Cluster)                         │
└─────────────────────────────────────────────────────────────────────┘

  USER / BROWSER / k6 LOAD TESTER
        │
        │  http://streamshield.local
        ▼
┌───────────────────────────────────────────────────────────────────┐
│                    NGINX INGRESS CONTROLLER                        │
│                  (minikube addons enable ingress)                  │
│                                                                   │
│  SMART ROLLOUT:                   UNSAFE ROLLOUT:                 │
│  ┌──────────────────────────┐     ┌──────────────────────────┐   │
│  │ ingress-main.yaml        │     │ unsafe-rollout.yaml       │   │
│  │ 100% → Blue (v1)         │     │ 100% → Green (v2)         │   │
│  └──────────────────────────┘     └──────────────────────────┘   │
│  ┌──────────────────────────┐                                     │
│  │ ingress-canary-10.yaml   │ ← 10% of public traffic → Green    │
│  │ canary-weight: 10        │                                     │
│  └──────────────────────────┘                                     │
│  ┌──────────────────────────┐                                     │
│  │ ingress-internal-team    │ ← X-Internal-Team: true → Green    │
│  │ canary-by-header         │                                     │
│  └──────────────────────────┘                                     │
└───────────────────────────────────────────────────────────────────┘
         │                                │
         ▼                                ▼
┌─────────────────┐              ┌─────────────────────┐
│  BLUE SERVICE   │              │   GREEN SERVICE      │
│  (NodePort      │              │   (NodePort          │
│   :30081)       │              │    :30082)           │
└─────────────────┘              └─────────────────────┘
         │                                │
         ▼                                ▼
┌─────────────────────────┐   ┌──────────────────────────────────┐
│  BLUE DEPLOYMENT (v1)   │   │  GREEN DEPLOYMENT (v2)           │
│  streamshield-blue      │   │  streamshield-green              │
│  replicas: 2            │   │  replicas: 2                     │
│  image: v1:latest       │   │  image: v2:latest                │
│  ─────────────────────  │   │  ──────────────────────────────  │
│  Pod 1  │  Pod 2        │   │  Pod 1           │  Pod 2        │
│  ┌────┐  │  ┌────┐      │   │  ┌─────────────┐ │  ┌─────────┐ │
│  │ v1 │  │  │ v1 │      │   │  │ v2 + chaos  │ │  │ v2      │ │
│  └────┘  │  └────┘      │   │  └─────────────┘ │  └─────────┘ │
│           │              │   │                  │              │
│  Flask :5000             │   │  Flask :5000 + chaos_mode       │
│  /health (probe)         │   │  /health  /chaos/on  /chaos/off │
│  /metrics (prometheus)   │   │  /metrics /simulator/status     │
└─────────────────────────┘   └──────────────────────────────────┘
         │                                │
         └─────────────┬──────────────────┘
                       │
                       ▼
         ┌─────────────────────────┐
         │   HEALTH SCORE ENGINE   │
         │   (scripts/*.ps1)        │
         │                         │
         │  Probes /watch × 20     │
         │  Measures latency       │
         │  Counts failures        │
         │  Calculates score 0-100 │
         │  Triggers rollback      │
         └─────────────────────────┘
                       │
                       ▼
         ┌─────────────────────────┐
         │   AUTO ROLLBACK ENGINE  │
         │   (auto-rollback.ps1)   │
         │                         │
         │  IF score < 70:         │
         │    delete canary ingress│
         │    apply main ingress   │
         │    restore v1 traffic   │
         └─────────────────────────┘
                       │
                       ▼
         ┌─────────────────────────┐
         │   MONITORING LAYER      │
         │   (Phase 4 optional)    │
         │                         │
         │  Prometheus             │
         │  → scrapes /metrics     │
         │  → stores time-series   │
         │                         │
         │  Grafana                │
         │  → dashboards           │
         │  → alerts               │
         └─────────────────────────┘
                       │
                       ▼
         ┌─────────────────────────┐
         │   CI PIPELINE           │
         │   (.github/workflows)   │
         │                         │
         │  GitHub Actions         │
         │  → syntax check         │
         │  → docker build         │
         │  → image validation     │
         └─────────────────────────┘
```

---

## Component Details

### Blue Environment (v1 — Stable Production)

| Property | Value |
|---|---|
| Deployment | `streamshield-blue` |
| Image | `streamshield-v1:latest` |
| Replicas | 2 |
| Service | `streamshield-blue-service` (NodePort 30081) |
| Role | Stable production — receives majority of user traffic |
| Key Endpoints | `/` `/health` `/movies` `/watch` `/release-mode` `/metrics` |
| Health Probes | Readiness + Liveness on `/health` |

### Green Environment (v2 — Release Candidate)

| Property | Value |
|---|---|
| Deployment | `streamshield-green` |
| Image | `streamshield-v2:latest` |
| Replicas | 2 |
| Service | `streamshield-green-service` (NodePort 30082) |
| Role | New release under validation — canary users only |
| Key Endpoints | All v1 endpoints + `/chaos/on` `/chaos/off` `/trending` `/simulator/status` |
| Chaos Mode | `chaos_mode = True` → /watch returns random 500s and latency |

### NGINX Ingress Layer

| File | Purpose | Canary Annotation |
|---|---|---|
| `ingress-main.yaml` | 100% → v1 Blue | None (primary) |
| `ingress-canary-10.yaml` | 10% → v2 Green | `canary-weight: "10"` |
| `ingress-internal-team.yaml` | Header → v2 Green | `canary-by-header: X-Internal-Team` |
| `unsafe-rollout.yaml` | 100% → v2 Green | None (replaces main) |

### Health Score Engine

| Metric | Threshold | Penalty |
|---|---|---|
| Error Rate | > 5% | −30 |
| Playback Failure Rate | > 8% | −25 |
| Average Latency | > 800ms | −20 |
| Pod Readiness | Not all ready | −15 |
| Restart Count | > 0 | −10 |

Rollback triggers if: score < 70 OR error rate > 5% OR latency > 800ms

### Load Testing (k6)

- **Tool**: k6 open-source load tester
- **Script**: `load-tests/viewer-load.js`
- **Virtual Users**: 50 concurrent streaming viewers
- **Duration**: 30 seconds
- **Endpoints**: `/` → `/movies` → `/watch`
- **Target URL**: `http://streamshield.local` (configurable via `BASE_URL` env var)

### CI Pipeline (GitHub Actions)

- **Trigger**: Push / Pull Request to any branch
- **Steps**: Checkout → Python setup → Syntax check → Docker build
- **Note**: Does not deploy to Kubernetes (Minikube is local-only)

---

## Data Flow — Smart Rollout

```
User Request
    → streamshield.local
    → NGINX Ingress (evaluates canary rules)
    → 90% → Blue Service → Blue Pod (v1) → Stable response
    → 10% → Green Service → Green Pod (v2) → New release response
    → QA with header → Green Service → Green Pod (v2) → Internal test
    → /metrics scraped by Prometheus every 15s
    → Grafana reads Prometheus → shows dashboards
    → health-score.ps1 probes /watch → calculates score
    → auto-rollback.ps1 → if score < 70 → delete canary → restore v1
```

## Data Flow — Unsafe Rollout

```
User Request
    → streamshield.local
    → NGINX Ingress (unsafe-rollout.yaml — no canary)
    → 100% → Green Service → Green Pod (v2 with chaos ON)
    → 40% of requests → HTTP 500 error
    → 30% of requests → 2-5s latency spike
    → health-score.ps1 → score < 40 → ROLLBACK REQUIRED
    → No auto rollback configured → users stay on broken v2
    → DevOps lesson: This is why you always use canary deployments
```
