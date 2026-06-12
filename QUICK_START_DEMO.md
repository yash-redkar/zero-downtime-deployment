# 🚀 Quick Start Demo Guide

This guide is for the day of your capstone presentation. Follow these exact steps to run a flawless demo of the **StreamShield Simulator**.

---

## 1. Pre-Demo Setup (Before the presentation)

Make sure your Minikube cluster is running and your Windows `hosts` file is configured.

```powershell
# 1. Start your Kubernetes cluster
minikube start --driver=docker

# 2. Get your Minikube IP
minikube ip

# 3. Add to your Windows hosts file (C:\Windows\System32\drivers\etc\hosts)
# <MINIKUBE_IP> streamshield.local
```

### Pre-load Docker Images into Minikube
```powershell
# In the StreamShield root directory
minikube image load streamshield-v1:latest
minikube image load streamshield-v2:latest
```

### Apply Base Infrastructure
```powershell
kubectl apply -f k8s\namespace.yaml
kubectl apply -f k8s\blue-deployment.yaml
kubectl apply -f k8s\blue-service.yaml
kubectl apply -f k8s\green-deployment.yaml
kubectl apply -f k8s\green-service.yaml
```

---

## 2. Verify the System (5 minutes before presenting)

Run the automated system verification script to ensure everything is ready:

```powershell
.\scripts\verify-system.ps1
```
*Expected Output: All checks PASS (Green).*

---

## 3. Run the Final Presentation Demo

When you are ready to present, you only need to run ONE command. This interactive script will guide you through the entire presentation, pausing for you to explain each phase to your audience.

```powershell
.\scripts\run-final-demo.ps1
```

### Demo Flow:
The script will walk you through:
1. **Current System State:** Shows v1 and v2 running independently.
2. **Unsafe Rollout:** Simulates a direct push of v2 to 100% of users. Chaos mode is enabled, and the load test shows massive failures.
3. **Health Score Check:** Demonstrates how the system calculates a failing grade.
4. **Reset:** Cleans up the bad deployment.
5. **Smart Rollout:** Demonstrates a safe release. QA gets early access, and only 10% canary traffic hits v2. Load test shows 90% of users remain unaffected by chaos mode.
6. **Auto Rollback:** The system detects the canary issues and safely restores v1 automatically.

---

## 💡 Pro Tips for Presenting
- Keep your browser open to `http://streamshield.local`. Refresh the page during different phases to show the UI changing (or breaking during Unsafe Rollout).
- Keep an eye on the `k6` load test output. Highlight the high failure rate during the Unsafe Rollout, and the very low (canary-only) failure rate during the Smart Rollout.
- Let the `auto-rollback.ps1` script do its magic—don't interrupt it. It perfectly illustrates the value of automated SRE practices.
