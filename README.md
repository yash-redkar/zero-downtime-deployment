# StreamShield Simulator

## Zero-Downtime Deployment System for Streaming Platforms

StreamShield Simulator is a DevOps/SRE capstone project that demonstrates how a streaming platform can safely release a new application version without downtime.

The project simulates two release strategies:

1. **Unsafe Rollout Mode** — a bad deployment where the new version is released directly to all users.
2. **Smart Rollout Mode** — an industry-style deployment strategy using blue-green deployment, canary traffic, internal QA rollout, health-score monitoring, and automated rollback.

This project was built to demonstrate practical DevOps concepts including Git, GitHub, GitHub Issues, GitHub Actions, Docker, Kubernetes, YAML, artifacts, versioning, rollback strategy, and release automation.

---

## Project Objective

Streaming platforms frequently release new features such as:

* new video player experience
* recommendation engine updates
* live event pages
* trending content sections
* UI/UX improvements
* performance optimizations

If a faulty release is pushed directly to all users, it can cause:

* video playback failures
* buffering
* high latency
* 500 errors
* user complaints
* loss of viewer trust
* revenue impact during live events

The objective of StreamShield is to simulate how modern DevOps teams reduce this risk using controlled rollout strategies and automated recovery.

---

## Business Problem

In a streaming business, downtime is not only a technical issue. It directly affects user experience, brand reputation, watch time, subscription trust, and revenue.

For example, if a new video player update fails during a live sports event, thousands of users may experience buffering or playback errors. StreamShield demonstrates how such risk can be reduced by releasing the new version gradually, monitoring its health, and rolling back automatically if the release becomes unhealthy.

---

## Solution Overview

StreamShield solves the release risk problem by using:

* **Blue-Green Deployment**
* **Canary Rollout**
* **Internal QA Rollout**
* **Health Score Based Monitoring**
* **Automated Rollback**
* **GitHub Actions CI/CD**
* **Docker Containerization**
* **Kubernetes Deployment**
* **Release Artifacts and Versioning**

---

## Core Features

### 1. Blue-Green Deployment

The project runs two environments:

| Environment | Version | Purpose                   |
| ----------- | ------- | ------------------------- |
| Blue        | v1      | Stable production version |
| Green       | v2      | New release candidate     |

The stable version continues serving users while the new version is tested separately.

---

### 2. Unsafe Rollout Mode

Unsafe Rollout Mode simulates a bad deployment strategy.

In this mode:

* 100% traffic is routed to v2
* internal QA is skipped
* canary rollout is disabled
* health score is not used
* rollback is not available

This mode shows what happens when a risky release is pushed directly to all users.

---

### 3. Smart Rollout Mode

Smart Rollout Mode simulates a safer DevOps release strategy.

In this mode:

* v1 remains the stable production version
* v2 is first exposed to internal QA users
* only 10% traffic is routed to v2 using canary routing
* release health is monitored
* rollback can restore stable v1

This reduces the blast radius of a bad release.

---

### 4. Internal QA Rollout

Internal users can access v2 before normal users using header-based routing.

Example:

```bash
curl -H "X-Internal-Team: true" http://streamshield.local
```

This allows developers, QA engineers, and product teams to test the new release before public users are affected.

---

### 5. Canary Traffic Routing

Canary routing sends only a small percentage of public traffic to the new release.

Example:

```text
90% traffic -> v1 stable version
10% traffic -> v2 new release
```

This helps detect issues early while protecting most users.

---

### 6. Health Score Engine

The release health score is calculated using multiple signals:

* error rate
* playback failure rate
* response latency
* pod readiness
* restart count

Health score classification:

| Score    | Status            |
| -------- | ----------------- |
| 90-100   | Excellent         |
| 75-89    | Healthy           |
| 60-74    | Risky             |
| Below 60 | Rollback Required |

Rollback condition:

```text
Health Score < 70
OR Error Rate > 5%
OR Playback Failure Rate > 8%
OR Latency > 800ms
```

---

### 7. Automated Rollback

The project includes rollback automation using GitHub Actions.

Rollback workflow:

```text
.github/workflows/rollback.yml
```

The rollback workflow represents a production-style recovery process. If v2 becomes unhealthy, the rollback workflow restores the stable Blue environment and removes risky Green/canary traffic.

---

### 8. GitHub Actions CI/CD

The project includes GitHub Actions workflows to demonstrate CI/CD automation.

The CI/CD workflow validates:

* Python application syntax
* Docker image builds
* Kubernetes YAML files
* release artifact generation
* version metadata

The rollback workflow supports:

* manual rollback trigger
* stable environment restoration
* rollback visibility in GitHub Actions

---

## Architecture

```text
                         +----------------------+
                         |      GitHub Repo     |
                         | Issues / PRs / Tags |
                         +----------+-----------+
                                    |
                                    v
                         +----------------------+
                         |   GitHub Actions CI  |
                         | Build / Validate     |
                         | Artifact / Version   |
                         +----------+-----------+
                                    |
                                    v
+----------------+        +----------------------+        +----------------+
| Streaming User | -----> |   NGINX Ingress      | -----> | Blue v1 App    |
+----------------+        | Traffic Management   |        | Stable Version |
                          +----------+-----------+        +----------------+
                                     |
                                     | 10% Canary / Internal QA
                                     v
                              +----------------+
                              | Green v2 App   |
                              | New Release    |
                              +----------------+
                                     |
                                     v
                              +----------------+
                              | Health Score   |
                              | Error/Latency  |
                              | Pod Health     |
                              +----------------+
                                     |
                                     v
                              +----------------+
                              | Auto Rollback  |
                              | Restore v1     |
                              +----------------+
```

---

## Tech Stack

| Category           | Tools                            |
| ------------------ | -------------------------------- |
| Application        | Python Flask                     |
| Containerization   | Docker                           |
| Orchestration      | Kubernetes, Minikube             |
| Traffic Routing    | NGINX Ingress                    |
| CI/CD              | GitHub Actions                   |
| Version Control    | Git, GitHub                      |
| Monitoring Concept | Prometheus Metrics, Health Score |
| Automation         | PowerShell Scripts               |
| Load Simulation    | k6 / curl fallback               |
| Documentation      | Markdown, Runbook                |

---

## Repository Structure

```text
StreamShield/
│
├── app/
│   ├── v1/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   │
│   └── v2/
│       ├── app.py
│       ├── requirements.txt
│       └── Dockerfile
│
├── k8s/
│   ├── namespace.yaml
│   ├── blue-deployment.yaml
│   ├── blue-service.yaml
│   ├── green-deployment.yaml
│   ├── green-service.yaml
│   ├── ingress-main.yaml
│   ├── ingress-canary-10.yaml
│   ├── ingress-internal-team.yaml
│   └── unsafe-rollout.yaml
│
├── load-tests/
│   └── viewer-load.js
│
├── scripts/
│   ├── unsafe-rollout.ps1
│   ├── smart-rollout.ps1
│   ├── reset-rollout.ps1
│   ├── health-score.ps1
│   ├── rollback.ps1
│   ├── auto-rollback.ps1
│   ├── verify-system.ps1
│   └── run-final-demo.ps1
│
├── monitoring/
│   ├── prometheus-install.md
│   ├── grafana-dashboard-notes.md
│   └── health-score-rules.md
│
├── docs/
│   ├── architecture.md
│   ├── business-case.md
│   ├── runbook.md
│   └── demo-script.md
│
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── rollback.yml
│
├── README.md
└── .gitignore
```

---

## Application Versions

### v1 — Stable Blue Environment

v1 represents the stable production version.

Main features:

* stable streaming homepage
* movie catalog
* stable watch page
* health endpoint
* metrics endpoint

Endpoints:

```text
/
 /health
 /movies
 /watch
 /release-mode
 /metrics
```

---

### v2 — Green Release Environment

v2 represents the new release candidate.

Main features:

* smart video player
* trending section
* simulated recommendations
* release mode simulator
* chaos mode for bad release simulation

Endpoints:

```text
/
 /health
 /movies
 /watch
 /trending
 /chaos/on
 /chaos/off
 /simulator/status
 /release-mode/unsafe
 /release-mode/smart
 /metrics
```

---

## Prerequisites

Install the following tools:

* Git
* Docker Desktop
* Minikube
* kubectl
* PowerShell
* k6 optional
* VS Code

Verify installation:

```bash
docker --version
minikube version
kubectl version --client
git --version
```

---

## Running the Project Locally with Docker

Go to the project root:

```bash
cd /d/Devops/StreamShield
```

Build Docker images:

```bash
docker build -t streamshield-v1:latest ./app/v1
docker build -t streamshield-v2:latest ./app/v2
```

Run v1:

```bash
docker run -p 5001:5000 streamshield-v1:latest
```

Open:

```text
http://localhost:5001
```

Run v2:

```bash
docker run -p 5002:5000 streamshield-v2:latest
```

Open:

```text
http://localhost:5002
```

---

## Kubernetes Deployment

Start Minikube:

```bash
minikube start --driver=docker
```

Load Docker images into Minikube:

```bash
minikube image load streamshield-v1:latest
minikube image load streamshield-v2:latest
```

Apply Kubernetes manifests:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/blue-deployment.yaml
kubectl apply -f k8s/blue-service.yaml
kubectl apply -f k8s/green-deployment.yaml
kubectl apply -f k8s/green-service.yaml
```

Verify:

```bash
kubectl get all -n streamshield
```

Expected result:

```text
Blue pods running
Green pods running
Blue service created
Green service created
```

Open v1:

```bash
minikube service streamshield-blue-service -n streamshield
```

Open v2:

```bash
minikube service streamshield-green-service -n streamshield
```

---

## Ingress Setup

Enable NGINX Ingress:

```bash
minikube addons enable ingress
```

Check ingress controller:

```bash
kubectl get pods -n ingress-nginx
```

Get Minikube IP:

```bash
minikube ip
```

Add the IP to Windows hosts file:

```text
C:\Windows\System32\drivers\etc\hosts
```

Example:

```text
192.168.49.2 streamshield.local
```

Apply main ingress:

```bash
kubectl apply -f k8s/ingress-main.yaml
```

Test:

```bash
curl http://streamshield.local
```

---

## Rollout Modes

### Unsafe Rollout Mode

Unsafe rollout sends all traffic to v2.

Run:

```bash
powershell -ExecutionPolicy Bypass -File ./scripts/unsafe-rollout.ps1
```

This mode demonstrates:

* 100% traffic to v2
* no internal QA
* no canary
* no rollback
* high user impact during bad release

---

### Smart Rollout Mode

Smart rollout uses stable v1, internal QA, and canary traffic.

Run:

```bash
powershell -ExecutionPolicy Bypass -File ./scripts/smart-rollout.ps1
```

This mode demonstrates:

* stable v1 remains primary
* internal QA can test v2
* 10% canary traffic goes to v2
* majority users remain protected

---

### Reset Rollout

Run:

```bash
powershell -ExecutionPolicy Bypass -File ./scripts/reset-rollout.ps1
```

This restores traffic back to stable v1.

---

## Health Score and Rollback

Run health score:

```bash
powershell -ExecutionPolicy Bypass -File ./scripts/health-score.ps1
```

Run auto rollback:

```bash
powershell -ExecutionPolicy Bypass -File ./scripts/auto-rollback.ps1
```

Run GitHub Actions rollback workflow:

```text
GitHub Repo -> Actions -> Rollback Workflow -> Run workflow
```

---

## Final Demo Command

Run the complete guided demo:

```bash
powershell -ExecutionPolicy Bypass -File ./scripts/run-final-demo.ps1
```

The demo shows:

1. system verification
2. unsafe rollout
3. bad release behavior
4. health score check
5. reset
6. smart rollout
7. auto rollback
8. final comparison

---

## GitHub Workflow

This project uses GitHub Issues to track DevOps phases:

* application development
* Docker containerization
* Kubernetes deployment
* canary rollout
* release simulator
* dashboard
* health score
* rollback workflow
* runbook

The project also uses:

* phase-wise commits
* GitHub Actions
* build artifacts
* version tags
* rollback workflow

---

## CI/CD Pipeline

The GitHub Actions CI pipeline performs:

* source checkout
* Python dependency installation
* Python syntax validation
* Docker image build validation
* Kubernetes YAML validation
* release artifact creation
* build metadata generation

Workflow file:

```text
.github/workflows/ci.yml
```

Rollback workflow file:

```text
.github/workflows/rollback.yml
```

---

## Versioning

Recommended version tags:

```bash
git tag -a v0.2.0 -m "v0.2.0: Blue-green Kubernetes foundation completed"
git push origin v0.2.0
```

Final release:

```bash
git tag -a v1.0.0 -m "v1.0.0: Final StreamShield zero-downtime release simulator"
git push origin v1.0.0
```

---

## Useful Commands

Check Kubernetes resources:

```bash
kubectl get all -n streamshield
```

Check ingress:

```bash
kubectl get ingress -n streamshield
```

Check pods:

```bash
kubectl get pods -n streamshield
```

View blue logs:

```bash
kubectl logs deployment/streamshield-blue -n streamshield
```

View green logs:

```bash
kubectl logs deployment/streamshield-green -n streamshield
```

Delete environment:

```bash
kubectl delete namespace streamshield
```

---

## Project Phases

| Phase   | Description                                         | Status      |
| ------- | --------------------------------------------------- | ----------- |
| Phase 1 | Build v1/v2 simulator apps and Docker images        | Completed   |
| Phase 2 | Deploy blue-green environments on Kubernetes        | Completed   |
| Phase 3 | Add unsafe/smart rollout modes and ingress routing  | In Progress |
| Phase 4 | Add health score, rollback, monitoring, and runbook | In Progress |

---

## Business Value

StreamShield provides business value by helping companies release faster while reducing production risk.

Benefits:

* reduces downtime
* protects viewer experience
* limits blast radius of bad releases
* improves deployment confidence
* enables faster recovery
* supports business continuity
* reduces manual firefighting

Although demonstrated for a streaming platform, the same approach can be extended to:

* fintech platforms
* e-commerce platforms
* healthcare systems
* ed-tech platforms
* SaaS products
* live event platforms

---

## Known Limitations

This is a local capstone simulation.

Current limitations:

* Minikube is used instead of a cloud Kubernetes cluster
* GitHub Actions does not directly deploy to local Minikube
* Prometheus/Grafana are optional visual monitoring components
* health score is simulated using local scripts and request checks
* production secrets and cloud registry are not configured

---

## Future Improvements

Future scope:

* deploy to cloud Kubernetes
* push Docker images to Docker Hub or GHCR
* add Argo Rollouts
* integrate Istio traffic management
* connect Prometheus Alertmanager to rollback workflow
* add Slack or Teams alerts
* add real-time Grafana dashboard
* add automated performance test reports
* add production-grade secrets management

---

## Team Roles

| Role                                    | Responsibility                                |
| --------------------------------------- | --------------------------------------------- |
| Application & Containerization Engineer | Flask apps and Docker images                  |
| Kubernetes Release Engineer             | Blue-green deployment and ingress routing     |
| CI/CD Release Engineer                  | GitHub Actions, artifacts, issues, versioning |
| SRE Automation Engineer                 | Health score, rollback, runbook, monitoring   |

---

## Final Project Summary

StreamShield Simulator demonstrates the complete DevOps lifecycle:

```text
Plan -> Code -> Build -> Containerize -> Deploy -> Route Traffic -> Monitor -> Rollback -> Document
```

It shows how modern DevOps teams protect users and businesses during software releases by combining Kubernetes, Docker, GitHub Actions, canary routing, health scoring, and automated rollback.

The project is not only about deploying containers. It is about protecting business continuity during software releases.
