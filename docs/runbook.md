# StreamShield Simulator — Operations Runbook
## Incident Response and Troubleshooting Guide

> This runbook covers how to detect, diagnose, and recover from issues
> during a StreamShield demo or deployment.

---

## 1. How to Detect an Issue

### Signs of a bad release

| Signal | Where to See It | What It Means |
|---|---|---|
| HTTP 500 errors | `curl http://streamshield.local/watch` | v2 chaos mode is on or app crashed |
| High latency (>2s) | Browser or k6 output | Chaos latency simulation or pod overload |
| Pods not ready | `kubectl get pods -n streamshield` | Readiness probe failing |
| CrashLoopBackOff | `kubectl get pods -n streamshield` | App crashing on startup |
| Health score < 70 | `.\scripts\health-score.ps1` | Multiple metrics failing |

### Quick first check

```powershell
# Run this first whenever something seems wrong
kubectl get all -n streamshield
.\scripts\health-score.ps1
```

---

## 2. How to Check Pod Status

```powershell
# See all pods and their status
kubectl get pods -n streamshield

# Watch pods update in real time (Ctrl+C to stop)
kubectl get pods -n streamshield -w

# Get detailed event log for a specific pod
kubectl describe pod <pod-name> -n streamshield
# (Replace <pod-name> with the actual name from kubectl get pods)
```

**Status meanings:**

| STATUS | Meaning | Action |
|---|---|---|
| `Running` | Pod is healthy | No action needed |
| `ContainerCreating` | Pod is starting up | Wait 30–60 seconds |
| `Pending` | No node has enough resources | Check resources (Step 8) |
| `CrashLoopBackOff` | App keeps crashing | Check logs (Step 3) |
| `ImagePullBackOff` | Image not found | Reload image (Step 8) |
| `OOMKilled` | Out of memory | Increase memory limits |

---

## 3. How to Check Logs

```powershell
# Get logs from a specific pod
kubectl logs <pod-name> -n streamshield

# Stream live logs (follow mode)
kubectl logs -f <pod-name> -n streamshield

# Get logs from previous crashed container
kubectl logs <pod-name> -n streamshield --previous

# Get logs from blue deployment (latest pod)
kubectl logs -l environment=blue -n streamshield --tail=50

# Get logs from green deployment
kubectl logs -l environment=green -n streamshield --tail=50
```

---

## 4. How to Run Health Score Check

```powershell
cd D:\Devops\StreamShield

# Run health score probe
.\scripts\health-score.ps1
```

**Interpreting results:**

| Score | Action |
|---|---|
| 90–100 | ✅ Release is healthy. No action needed. |
| 75–89 | 🟡 Monitor closely. Watch for trends. |
| 60–74 | 🟠 Risky. Consider slowing canary or manual review. |
| Below 60 | 🔴 Run auto-rollback or manual rollback immediately. |

---

## 5. How to Rollback Manually

**Option A — Manual Rollback Script (recommended):**
```powershell
cd D:\Devops\StreamShield
.\scripts\rollback.ps1
```

**Option B — Auto Rollback Script (calculates score first):**
```powershell
.\scripts\auto-rollback.ps1
```

**Option C — Raw kubectl commands (emergency):**
```powershell
# Turn off chaos mode
curl http://streamshield.local/chaos/off

# Remove all canary and unsafe ingresses
kubectl delete -f k8s/ingress-canary-10.yaml      --ignore-not-found=true
kubectl delete -f k8s/ingress-internal-team.yaml  --ignore-not-found=true
kubectl delete -f k8s/unsafe-rollout.yaml          --ignore-not-found=true
kubectl delete -f k8s/ingress-main.yaml            --ignore-not-found=true

# Restore main ingress pointing to v1
kubectl apply -f k8s/ingress-main.yaml

# Verify
kubectl get ingress -n streamshield
```

---

## 6. How to Reset the Demo

To reset everything to a clean slate between demo runs:

```powershell
cd D:\Devops\StreamShield
.\scripts\reset-rollout.ps1
```

This will:
1. Disable chaos mode
2. Delete all rollout ingresses
3. Re-apply the main ingress to v1
4. Confirm the reset is complete

---

## 7. How to Recover if Ingress Fails

**Symptoms:** `streamshield.local` does not respond, or wrong version is shown.

**Step 1 — Check ingress state:**
```powershell
kubectl get ingress -n streamshield
kubectl describe ingress -n streamshield
```

**Step 2 — Check ingress controller:**
```powershell
kubectl get pods -n ingress-nginx
```

If ingress controller pod is not `Running`:
```powershell
# Re-enable the ingress addon
minikube addons disable ingress
Start-Sleep 5
minikube addons enable ingress

# Wait for controller to be Ready (~60 seconds)
kubectl get pods -n ingress-nginx -w
```

**Step 3 — Re-apply ingresses:**
```powershell
kubectl apply -f k8s/ingress-main.yaml
```

**Step 4 — Use port-forward as emergency fallback:**
```powershell
# Access v1 directly (bypasses ingress entirely)
kubectl port-forward svc/streamshield-blue-service 8080:80 -n streamshield
# Open: http://localhost:8080

# Access v2 directly
kubectl port-forward svc/streamshield-green-service 8081:80 -n streamshield
# Open: http://localhost:8081
```

---

## 8. How to Recover from ImagePullBackOff

**Symptoms:** Pod STATUS shows `ImagePullBackOff` or `ErrImagePull`

**Cause:** Kubernetes cannot find the Docker image. The image was built locally but not loaded into Minikube's internal registry.

**Fix:**
```powershell
# Step 1: Verify image exists in your local Docker
docker images | Select-String "streamshield"

# Step 2: If image doesn't exist, rebuild it
docker build -t streamshield-v1:latest ./app/v1
docker build -t streamshield-v2:latest ./app/v2

# Step 3: Load into Minikube
minikube image load streamshield-v1:latest
minikube image load streamshield-v2:latest

# Step 4: Confirm images are in Minikube
minikube image ls | Select-String "streamshield"

# Step 5: Restart the deployments
kubectl rollout restart deployment/streamshield-blue  -n streamshield
kubectl rollout restart deployment/streamshield-green -n streamshield

# Step 6: Watch pods recover
kubectl get pods -n streamshield -w
```

---

## 9. How to Recover if streamshield.local Does Not Open

**Symptoms:** Browser shows "This site can't be reached" or `curl` hangs.

**Step 1 — Get current Minikube IP:**
```powershell
minikube ip
# Example output: 192.168.49.2
```

**Step 2 — Check your hosts file:**
```powershell
# View current hosts file entries
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String "streamshield"
```

**Step 3 — Update hosts file if IP changed:**
1. Open Notepad **as Administrator**
2. Open `C:\Windows\System32\drivers\etc\hosts`
3. Find the existing `streamshield.local` line and update the IP:
```
192.168.49.2 streamshield.local
```
4. Save the file.

**Step 4 — Flush DNS cache:**
```powershell
ipconfig /flushdns
```

**Step 5 — Test with curl:**
```powershell
curl http://streamshield.local/health
# Expected: {"status": "healthy", "version": "v1", ...}
```

**Step 6 — Fallback: Use port-forward instead:**
```powershell
kubectl port-forward svc/streamshield-blue-service 8080:80 -n streamshield
# Access at: http://localhost:8080
```

---

## 10. Complete Recovery from Scratch

If everything is broken and you want to start fresh:

```powershell
# Step 1: Delete Minikube cluster
minikube delete

# Step 2: Start fresh
minikube start --driver=docker

# Step 3: Load images
minikube image load streamshield-v1:latest
minikube image load streamshield-v2:latest

# Step 4: Apply all manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/blue-deployment.yaml
kubectl apply -f k8s/blue-service.yaml
kubectl apply -f k8s/green-deployment.yaml
kubectl apply -f k8s/green-service.yaml

# Step 5: Enable ingress
minikube addons enable ingress
# Wait 60 seconds

# Step 6: Update hosts file with new IP
minikube ip   # Note the new IP
# Edit C:\Windows\System32\drivers\etc\hosts → update streamshield.local

# Step 7: Apply main ingress
kubectl apply -f k8s/ingress-main.yaml

# Step 8: Verify everything
.\scripts\verify-system.ps1
```
