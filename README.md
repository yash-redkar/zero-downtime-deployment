# StreamShield Simulator
## Zero-Downtime Release Simulator for Streaming Platforms

> **Phase 1 — Application & Docker Foundation** | **Phase 2 — Kubernetes Blue-Green Deployment** | **Phase 3 — Rollout Simulator Modes** | **Phase 4 — Health Score + Auto Rollback**

---

## 🎯 Problem Statement

Streaming platforms like Netflix, Hotstar, and Prime Video cannot risk broken releases during live cricket finals, movie premieres, or high-traffic events. A single bad deployment can cause:

- **Buffering** and playback failures for millions of users
- **HTTP 500 errors** under peak load
- **Revenue loss** and brand damage
- **No way to rollback** if done incorrectly

This project simulates exactly that challenge — and shows how **DevOps release strategies** solve it.

---

## 💡 Core Idea: Two Worlds, One Platform

| | Unsafe Rollout | Smart Rollout |
|---|---|---|
| **v2 traffic** | 100% users immediately | 10% canary users |
| **Internal QA** | Skipped | Enabled |
| **Canary rollout** | Disabled | Enabled |
| **Health monitoring** | None | Active |
| **Rollback** | Not available | Automatic |
| **Risk** | 🔴 Critical | 🟢 Low |

---

## 🔭 Phase 1 Scope

This phase builds the complete application and Docker foundation:

- ✅ **v1 Stable App** — Blue environment, 100% production traffic, always healthy
- ✅ **v2 Smart Release Simulator** — Green environment, mode switcher, new features
- ✅ **Dockerized Apps** — Both versions containerized with Docker
- ✅ **Chaos Simulation Endpoints** — Simulate buggy v2 releases on demand
- ✅ **Prometheus-compatible Metrics** — All endpoints export metrics for Phase 2

---

## 🛠️ Tools Used

| Tool | Purpose |
|---|---|
| **Python Flask** | Backend web framework for both v1 and v2 |
| **Docker** | Containerize both apps for consistent deployment |
| **prometheus_client** | Expose Prometheus metrics from Flask |
| **Minikube** | Local Kubernetes cluster for Phase 2 deployment |
| **kubectl** | Kubernetes CLI for managing deployments and services |
| **Git / GitHub** | Version control and source code management |
| **VS Code / Antigravity** | Development environment |

---

## 📁 Folder Structure

```
StreamShield/
├── app/
│   ├── v1/
│   │   ├── app.py              # v1 Stable Blue streaming platform
│   │   ├── requirements.txt    # Flask + prometheus_client
│   │   └── Dockerfile          # Docker build config for v1
│   └── v2/
│       ├── app.py              # v2 Smart Release Simulator (Green)
│       ├── requirements.txt    # Flask + prometheus_client
│       └── Dockerfile          # Docker build config for v2
├── k8s/                        # Phase 2 — Kubernetes manifests
│   ├── namespace.yaml          # streamshield namespace
│   ├── blue-deployment.yaml    # v1 Blue Deployment (2 replicas)
│   ├── blue-service.yaml       # NodePort Service → port 30081
│   ├── green-deployment.yaml   # v2 Green Deployment (2 replicas)
│   ├── green-service.yaml      # NodePort Service → port 30082
│   └── phase2-commands.md      # Step-by-step Minikube commands
├── README.md                   # This file
└── .gitignore                  # Python, Docker, VS Code ignores
```

---

## 🚀 How to Run Locally

### Run v1 (Stable Blue Environment)

```bash
cd app/v1
pip install -r requirements.txt
python app.py
```

Open: [http://localhost:5000](http://localhost:5000)

### Run v2 (Smart Release Simulator — Green)

```bash
cd app/v2
pip install -r requirements.txt
python app.py
```

Open: [http://localhost:5000](http://localhost:5000)

> **Note:** Run v1 and v2 on different ports if running simultaneously (use Docker).

---

## 🐳 Docker Build & Run

### Build Docker Images

```bash
# Build v1
docker build -t streamshield-v1:latest ./app/v1

# Build v2
docker build -t streamshield-v2:latest ./app/v2
```

### Run Docker Containers

```bash
# Run v1 on port 5001
docker run -p 5001:5000 streamshield-v1:latest

# Run v2 on port 5002
docker run -p 5002:5000 streamshield-v2:latest
```

Access:
- **v1 (Blue)** → [http://localhost:5001](http://localhost:5001)
- **v2 (Green)** → [http://localhost:5002](http://localhost:5002)

---

## 📡 Endpoint Reference

### v1 Endpoints (Stable Blue)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Homepage — streaming UI + DevOps status |
| `GET` | `/health` | Health check (JSON) |
| `GET` | `/movies` | Movie list (JSON) |
| `GET` | `/watch` | Stable video player (always works) |
| `GET` | `/release-mode` | Release mode info (JSON) |
| `GET` | `/metrics` | Prometheus metrics |

### v2 Endpoints (Smart Release Simulator — Green)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Homepage — mode switcher + simulator UI |
| `GET` | `/health` | Health check with chaos_mode (JSON) |
| `GET` | `/movies` | Movie list (JSON) |
| `GET` | `/watch` | Smart player (chaos-aware) |
| `GET` | `/trending` | Trending shows page |
| `GET` | `/chaos/on` | 💀 Enable chaos mode (bad release) |
| `GET` | `/chaos/off` | ✅ Disable chaos mode (restore) |
| `GET` | `/simulator/status` | Full simulator state (JSON) |
| `GET` | `/release-mode/unsafe` | Unsafe rollout info (JSON) |
| `GET` | `/release-mode/smart` | Smart rollout info (JSON) |
| `GET` | `/metrics` | Prometheus metrics |

---

## 💥 Chaos Mode Explained

Chaos mode simulates what happens during a **bad v2 release**:

### Enable Chaos Mode
```
GET http://localhost:5002/chaos/on
```
```json
{
  "chaos_mode": true,
  "message": "Bad release simulation enabled",
  "effect": "GET /watch will randomly return 500 errors and high latency"
}
```

**When chaos is ON, `/watch` will:**
- 40% of requests → Return **HTTP 500** (server crash simulation)
- 30% of requests → Add **2–5 seconds of latency** (high buffering simulation)
- Increment **playback_failures_total** Prometheus counter
- Show DevOps insight explaining why rollback is needed

### Disable Chaos Mode
```
GET http://localhost:5002/chaos/off
```
```json
{
  "chaos_mode": false,
  "message": "Bad release simulation disabled",
  "effect": "GET /watch is now operating normally"
}
```

**This simulates a successful rollback to v1.**

---

## 📊 Prometheus Metrics

Both v1 and v2 expose metrics at `/metrics`:

| Metric | Type | Description |
|---|---|---|
| `streamshield_http_requests_total` | Counter | Total HTTP requests (labels: version, endpoint, status) |
| `streamshield_request_latency_seconds` | Histogram | Request duration (labels: version, endpoint) |
| `streamshield_playback_failures_total` | Counter | Playback failures (labels: version) |
| `streamshield_chaos_mode` | Gauge | 1.0 = chaos ON, 0.0 = chaos OFF (v2 only) |

---

## ☸️ Phase 2: Kubernetes Blue-Green Deployment

This phase creates the **Kubernetes foundation** for zero-downtime deployment.
v1 runs as the stable Blue environment, while v2 runs as the Green release candidate.
In later phases, traffic will be shifted safely between these two environments.

### What Blue Means

The **Blue environment** (`streamshield-blue`) runs `streamshield-v1:latest`.
It represents the **current stable production version** — battle-tested, always healthy,
serving 100% of real users. Blue must never go down.

### What Green Means

The **Green environment** (`streamshield-green`) runs `streamshield-v2:latest`.
It represents the **release candidate** — a new version being validated in a real
Kubernetes environment before it is promoted to production. At this stage,
no real user traffic is sent to Green; it exists purely for testing and validation.

### Why Two Environments?

| Reason | Benefit |
|---|---|
| **Zero downtime** | Old version stays up while new version is validated |
| **Risk isolation** | A bug in Green cannot crash Blue |
| **Easy rollback** | If Green fails, Blue continues serving users |
| **Safe validation** | Probes and health checks confirm readiness before traffic shifts |
| **Side-by-side testing** | QA team can access both versions simultaneously |

### Phase 2 Tools

| Tool | Purpose |
|---|---|
| **Minikube** | Runs a local Kubernetes cluster inside Docker |
| **kubectl** | CLI to apply YAML manifests and manage resources |
| **Docker Desktop** | Provides the Docker daemon Minikube uses |
| **YAML manifests** | Declarative definitions for Deployments and Services |

### Quick Start (PowerShell)

```powershell
# Start Minikube
minikube start --driver=docker

# Load images into Minikube's internal registry
minikube image load streamshield-v1:latest
minikube image load streamshield-v2:latest

# Apply all manifests
kubectl apply -f k8s\namespace.yaml
kubectl apply -f k8s\blue-deployment.yaml
kubectl apply -f k8s\blue-service.yaml
kubectl apply -f k8s\green-deployment.yaml
kubectl apply -f k8s\green-service.yaml

# Open both environments in browser
minikube service streamshield-blue-service  -n streamshield   # v1 on port 30081
minikube service streamshield-green-service -n streamshield   # v2 on port 30082
```

> 📖 Full step-by-step guide with troubleshooting: [`k8s/phase2-commands.md`](k8s/phase2-commands.md)

### Expected Output After Deployment

```
kubectl get all -n streamshield

NAME                                      READY   STATUS    RESTARTS   AGE
pod/streamshield-blue-xxx-xxx             1/1     Running   0          3m
pod/streamshield-blue-xxx-xxx             1/1     Running   0          3m
pod/streamshield-green-xxx-xxx            1/1     Running   0          1m
pod/streamshield-green-xxx-xxx            1/1     Running   0          1m

NAME                                  TYPE       PORT(S)
service/streamshield-blue-service     NodePort   80:30081/TCP
service/streamshield-green-service    NodePort   80:30082/TCP

NAME                                 READY   UP-TO-DATE   AVAILABLE
deployment.apps/streamshield-blue    2/2     2            2
deployment.apps/streamshield-green   2/2     2            2
```

---

## 🚦 Phase 3: Rollout Simulator Modes

This phase adds two live rollout simulation modes using NGINX Ingress traffic control and k6 load testing, demonstrating the real-world difference between a bad and a safe release strategy.

### Unsafe Rollout Mode

**What it simulates:** A developer pushes v2 directly to 100% of production users with no validation.

- All traffic to `streamshield.local` is routed to v2 (Green)
- Chaos mode is enabled — v2 randomly returns 500 errors and high latency
- 50 virtual viewers hit the platform — most see failures
- No rollback is available — everyone is stuck on the broken version
- This shows why direct deployments are dangerous

### Smart Rollout Mode

**What it simulates:** A responsible team uses a staged release strategy.

| Stage | Who | Route |
|---|---|---|
| Stage 1 | All normal users | v1 (Blue) — stable, untouched |
| Stage 2 | QA team only | v2 (Green) via `X-Internal-Team: true` header |
| Stage 3 | 10% public canary | v2 (Green) via NGINX canary-weight |
| Stage 4 | Health + auto-rollback | Phase 4 (placeholder shown) |

- 90% of users stay safely on v1 even if v2 is broken
- Only the canary segment (~5 out of 50 virtual viewers) can be affected
- QA team can validate v2 privately before public canary goes live

### Why Load Testing?

Real production deployments don't get tested by manually refreshing a browser. k6 simulates **50 concurrent streaming viewers** hitting the platform simultaneously — the same kind of traffic that occurs during a live cricket final or movie premiere. This makes the failure impact of Unsafe Rollout visually obvious in the k6 output.

### Tools Used in Phase 3

| Tool | Purpose |
|---|---|
| **NGINX Ingress** | Traffic routing, canary splitting, header-based routing |
| **k6** | Open-source load testing tool — simulates virtual users |
| **Minikube Ingress Addon** | Enables NGINX ingress controller in Minikube |
| **PowerShell Scripts** | Automates the full rollout simulation workflow |

---

### ⚙️ One-Time Setup — Windows Hosts File

To access `streamshield.local` from your browser, you must add one line to your Windows hosts file:

**Step 1 — Get your Minikube IP:**
```powershell
minikube ip
# Example output: 192.168.49.2
```

**Step 2 — Edit the hosts file:**
1. Open **Notepad as Administrator** (right-click → Run as administrator)
2. Open file: `C:\Windows\System32\drivers\etc\hosts`
3. Add this line at the bottom (replace with your actual Minikube IP):
```
192.168.49.2 streamshield.local
```
4. Save the file.

**Step 3 — Verify it works:**
```powershell
curl http://streamshield.local
```

> ⚠️ You must redo this if your Minikube IP changes (after `minikube delete` + `minikube start`).

---

### 🚀 Enable NGINX Ingress Addon

```powershell
minikube addons enable ingress

# Wait for the controller to be ready (~60 seconds first time)
kubectl get pods -n ingress-nginx
```

---

### ▶️ Run the Simulations

**Option A — Unsafe Rollout (bad release demo):**
```powershell
cd D:\Devops\StreamShield
.\scripts\unsafe-rollout.ps1
```

**Option B — Smart Rollout (safe release demo):**
```powershell
cd D:\Devops\StreamShield
.\scripts\smart-rollout.ps1
```

**Reset to clean state between runs:**
```powershell
.\scripts\reset-rollout.ps1
```

---

### 📊 Demo Comparison — What You'll See

| | Unsafe Rollout | Smart Rollout |
|---|---|---|
| **Ingress** | `unsafe-rollout.yaml` | `ingress-main.yaml` + canary + header |
| **Traffic to v2** | 100% | ~10% public + QA team only |
| **Chaos mode** | ON — everyone suffers | ON — only canary users affected |
| **k6 failure rate** | ~40-70% requests fail | ~4-7% requests fail |
| **Users protected** | None | ~90% stay safely on v1 |
| **Rollback** | Not available | Phase 4 (placeholder shown) |

### 🔎 Test Commands (Manual)

```powershell
# Test as normal user (should get v1 in smart mode)
curl http://streamshield.local

# Test as QA team member (always gets v2)
curl -H "X-Internal-Team: true" http://streamshield.local

# Enable chaos on v2 via QA header
curl -H "X-Internal-Team: true" http://streamshield.local/chaos/on

# Check which version a request hits
curl http://streamshield.local/health

# Run k6 load test directly
k6 run load-tests/viewer-load.js

# Run against direct URL (skip ingress)
k6 run -e BASE_URL=http://localhost:5002 load-tests/viewer-load.js
```

---

## 🏥 Phase 4: Health Score + Auto Rollback

Phase 4 adds the final pieces of a professional DevOps release pipeline: a multi-signal health score engine, automated rollback, CI pipeline, and comprehensive documentation.

### The Health Score Engine

Relying on just "Error Rate" is dangerous for a streaming platform. A deployment might have a 2% error rate (looks healthy), but a 1.2-second average latency causing severe buffering and user abandonment. 

The **StreamShield Health Score (0-100)** combines 5 metrics into a single decision:

| Metric | Penalty Trigger | Penalty Points | Why? |
|---|---|---|---|
| Error Rate | > 5% | −30 | Industry standard SLO |
| Playback Failure | > 8% | −25 | Streaming-specific (buffering/black screen) |
| Avg Latency | > 800ms | −20 | >800ms causes player buffering |
| Pod Readiness | Not all ready | −15 | Risk of capacity overload |
| Restart Count | > 0 | −10 | Risk of crash loop |

**Decision Bands:**
- 90–100: ✅ Excellent
- 75–89: 🟡 Healthy
- 60–74: 🟠 Risky
- Below 60: 🔴 Rollback Required (or any single metric over threshold)

### Auto Rollback Engine

The `auto-rollback.ps1` script runs the health score probe. If it detects a bad release, it automatically:
1. Removes the 10% canary routing.
2. Removes the internal QA routing.
3. Restores the main ingress to point 100% of traffic back to v1 (Blue).
4. Disables chaos mode.
This takes < 30 seconds and requires **zero human intervention**.

### 🚀 Phase 4 Commands

```powershell
# Run the Health Score Engine (Probe + Calculate + Report)
.\scripts\health-score.ps1

# Run the Auto Rollback Engine (Probe + Auto-Revert if bad)
.\scripts\auto-rollback.ps1

# Run a Manual Rollback
.\scripts\rollback.ps1

# Guide through the full presentation demo
.\scripts\demo-compare.ps1

# Verify all system components before a demo
.\scripts\verify-system.ps1

# The definitive one-command final presentation execution
.\scripts\run-final-demo.ps1
```

### 📚 Phase 4 Documentation

Check out the newly added `docs/` and `monitoring/` directories for detailed guides:
- [PROJECT_AUDIT.md](PROJECT_AUDIT.md) — Complete audit status of the simulator components.
- [QUICK_START_DEMO.md](QUICK_START_DEMO.md) — Quick 5-minute setup and demo execution steps.
- [architecture.md](docs/architecture.md) — System design and data flow.
- [business-case.md](docs/business-case.md) — Why this matters financially.
- [runbook.md](docs/runbook.md) — Incident response guide.
- [demo-script.md](docs/demo-script.md) — Word-for-word presentation script.
- [health-score-rules.md](monitoring/health-score-rules.md) — Deep dive into the math.
- [prometheus-install.md](monitoring/prometheus-install.md) — Minikube Helm installation.

### 🤖 CI Pipeline

Added a GitHub Actions workflow (`.github/workflows/ci.yml`) that automatically tests and builds the v1 and v2 Docker images on every push to `main`.

---

## 🏁 Final Project Summary

**StreamShield Simulator** demonstrates the evolution of a release pipeline:

1. **Phase 1**: Built the core Flask applications, Dockerized them, and added a Chaos Mode to simulate bad releases.
2. **Phase 2**: Created the Kubernetes Blue-Green foundation using Deployments and Services on Minikube.
3. **Phase 3**: Added NGINX Ingress for traffic shaping (10% Canary, Header-based QA routing) and k6 for load testing.
4. **Phase 4**: Automated the decision-making process with a Health Score Engine and Auto Rollback, creating a self-healing deployment pipeline.

---

## 👤 Author

**DevOps Capstone Project — Complete (Phases 1-4)**
*StreamShield Simulator: Zero-Downtime Release Simulator for Streaming Platforms*

---

> 🛡️ *"Safe releases for high-traffic streaming platforms"*
