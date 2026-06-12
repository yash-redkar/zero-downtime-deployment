# StreamShield Phase 2 — Kubernetes Commands Reference
## Blue-Green Deployment on Minikube (Windows PowerShell)

> Run all commands in **Windows PowerShell** from the project root unless otherwise noted.

---

## Prerequisites

Before starting, ensure the following are installed and running:

| Tool | Verify With | Expected Output |
|---|---|---|
| Docker Desktop | `docker --version` | Docker version 24.x or higher |
| Minikube | `minikube version` | minikube version: v1.33.x or higher |
| kubectl | `kubectl version --client` | Client Version: v1.29.x or higher |

> ⚠️ **Docker Desktop must be running** before you start Minikube.

---

## Step 1 — Go to Project Root

```powershell
cd D:\Devops\StreamShield
```

Verify you can see the project structure:

```powershell
Get-ChildItem
```

Expected output:
```
Mode    Name
----    ----
d----   app
d----   k8s
-a---   .gitignore
-a---   README.md
```

---

## Step 2 — Start Minikube

```powershell
minikube start --driver=docker
```

> This starts a local Kubernetes cluster inside Docker.
> First run may take 2–5 minutes to download the Minikube ISO image.

Expected output (last few lines):
```
✅  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

---

## Step 3 — Verify the Kubernetes Node

```powershell
kubectl get nodes
```

Expected output:
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   1m    v1.30.x
```

> The node status must be **Ready** before proceeding.

---

## Step 4 — Load Docker Images into Minikube

> ⚠️ **CRITICAL STEP — Do not skip this.**
>
> Minikube runs its own internal Docker daemon, separate from your host Docker Desktop.
> Images built with `docker build` on your machine are NOT automatically available inside Minikube.
>
> You must explicitly load them using `minikube image load`.
> This is why the Kubernetes YAML uses `imagePullPolicy: Never` —
> it tells Kubernetes to use the locally loaded image and never try to pull from the internet.

```powershell
minikube image load streamshield-v1:latest
```

```powershell
minikube image load streamshield-v2:latest
```

> Each command may take 30–60 seconds depending on image size.

---

## Step 5 — Verify Images are Available in Minikube

```powershell
minikube image ls
```

Expected output (look for these two lines):
```
docker.io/library/streamshield-v1:latest
docker.io/library/streamshield-v2:latest
```

> If you don't see both images, re-run the `minikube image load` commands in Step 4.

---

## Step 6 — Create the Namespace

```powershell
kubectl apply -f k8s\namespace.yaml
```

Expected output:
```
namespace/streamshield created
```

Verify the namespace exists:

```powershell
kubectl get namespaces
```

Expected output (look for streamshield):
```
NAME              STATUS   AGE
default           Active   5m
kube-system       Active   5m
streamshield      Active   2s
```

---

## Step 7 — Deploy the Blue Environment (v1 Stable)

Apply the Deployment and Service for Blue (v1):

```powershell
kubectl apply -f k8s\blue-deployment.yaml
```

```powershell
kubectl apply -f k8s\blue-service.yaml
```

Expected output:
```
deployment.apps/streamshield-blue created
service/streamshield-blue-service created
```

---

## Step 8 — Verify Blue Pods and Services

Check that Blue pods are running:

```powershell
kubectl get pods -n streamshield
```

Expected output (wait 30–60 seconds for STATUS to become Running):
```
NAME                                 READY   STATUS    RESTARTS   AGE
streamshield-blue-xxxxxxxxx-xxxxx    1/1     Running   0          45s
streamshield-blue-xxxxxxxxx-xxxxx    1/1     Running   0          45s
```

> If STATUS is **ContainerCreating**, wait a few more seconds and re-run.
> If STATUS is **ImagePullBackOff**, see the Troubleshooting section below.

Check the Services:

```powershell
kubectl get svc -n streamshield
```

Expected output:
```
NAME                         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
streamshield-blue-service    NodePort   10.x.x.x        <none>        80:30081/TCP   1m
```

---

## Step 9 — Open Blue (v1) in Browser

```powershell
minikube service streamshield-blue-service -n streamshield
```

> This automatically finds the Minikube node IP and opens the correct URL in your browser.
> You should see the **StreamShield v1 — Stable Blue** homepage.

To get just the URL without opening the browser:

```powershell
minikube service streamshield-blue-service -n streamshield --url
```

---

## Step 10 — Deploy the Green Environment (v2 Release Candidate)

Apply the Deployment and Service for Green (v2):

```powershell
kubectl apply -f k8s\green-deployment.yaml
```

```powershell
kubectl apply -f k8s\green-service.yaml
```

Expected output:
```
deployment.apps/streamshield-green created
service/streamshield-green-service created
```

---

## Step 11 — Verify Green Pods and Services

Check all pods in the namespace — you should now see 4 pods total (2 blue + 2 green):

```powershell
kubectl get pods -n streamshield
```

Expected output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
streamshield-blue-xxxxxxxxx-xxxxx     1/1     Running   0          3m
streamshield-blue-xxxxxxxxx-xxxxx     1/1     Running   0          3m
streamshield-green-xxxxxxxxx-xxxxx    1/1     Running   0          30s
streamshield-green-xxxxxxxxx-xxxxx    1/1     Running   0          30s
```

Check both Services:

```powershell
kubectl get svc -n streamshield
```

Expected output:
```
NAME                          TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
streamshield-blue-service     NodePort   10.x.x.x      <none>        80:30081/TCP   4m
streamshield-green-service    NodePort   10.x.x.x      <none>        80:30082/TCP   30s
```

---

## Step 12 — Open Green (v2) in Browser

```powershell
minikube service streamshield-green-service -n streamshield
```

> You should see the **StreamShield v2 — Smart Release Simulator** homepage.
> You can now open both v1 and v2 side by side in separate browser tabs!

To get just the URL:

```powershell
minikube service streamshield-green-service -n streamshield --url
```

---

## Step 13 — Check All Resources at Once

Get a full overview of everything in the namespace:

```powershell
kubectl get all -n streamshield
```

Expected output:
```
NAME                                      READY   STATUS    RESTARTS   AGE
pod/streamshield-blue-xxxxxxxxx-xxxxx     1/1     Running   0          5m
pod/streamshield-blue-xxxxxxxxx-xxxxx     1/1     Running   0          5m
pod/streamshield-green-xxxxxxxxx-xxxxx    1/1     Running   0          2m
pod/streamshield-green-xxxxxxxxx-xxxxx    1/1     Running   0          2m

NAME                                  TYPE       CLUSTER-IP    PORT(S)        AGE
service/streamshield-blue-service     NodePort   10.x.x.x      80:30081/TCP   5m
service/streamshield-green-service    NodePort   10.x.x.x      80:30082/TCP   2m

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/streamshield-blue    2/2     2            2           5m
deployment.apps/streamshield-green   2/2     2            2           2m

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/streamshield-blue-xxxxxxxxx     2         2         2       5m
replicaset.apps/streamshield-green-xxxxxxxxx    2         2         2       2m
```

> ✅ **Success Criteria**: All 4 pods show `1/1 Running`, both Deployments show `2/2 READY`.

---

## Step 14 — Debug Commands

### Describe a pod (detailed events, probe status, errors)

```powershell
kubectl describe pod <pod-name> -n streamshield
```

Replace `<pod-name>` with the actual pod name from `kubectl get pods -n streamshield`.

Example:
```powershell
kubectl describe pod streamshield-blue-6d5b8f9c7-xr4k2 -n streamshield
```

### View pod logs (Flask app output)

```powershell
kubectl logs <pod-name> -n streamshield
```

### Stream live logs (follow mode)

```powershell
kubectl logs -f <pod-name> -n streamshield
```

### Check logs for a specific container

```powershell
kubectl logs <pod-name> -n streamshield -c streamshield-v1
```

### Check readiness/liveness probe status

```powershell
kubectl describe pod <pod-name> -n streamshield | Select-String -Pattern "Liveness|Readiness|Ready|Health"
```

### Check deployment rollout status

```powershell
kubectl rollout status deployment/streamshield-blue -n streamshield
kubectl rollout status deployment/streamshield-green -n streamshield
```

---

## Step 15 — Cleanup

### Delete everything in the namespace (pods, services, deployments)

```powershell
kubectl delete namespace streamshield
```

> This deletes the namespace and ALL resources inside it.
> Run `kubectl apply -f k8s\namespace.yaml` to recreate it fresh.

### Delete individual resources (without deleting the namespace)

```powershell
# Delete only the green deployment and service
kubectl delete -f k8s\green-deployment.yaml
kubectl delete -f k8s\green-service.yaml

# Delete only the blue deployment and service
kubectl delete -f k8s\blue-deployment.yaml
kubectl delete -f k8s\blue-service.yaml
```

### Stop Minikube (pause the cluster, preserves state)

```powershell
minikube stop
```

### Delete Minikube cluster entirely (full reset)

```powershell
minikube delete
```

---

## Troubleshooting

### ❌ Problem: ImagePullBackOff or ErrImagePull

**Symptom**: `kubectl get pods` shows `ImagePullBackOff` in STATUS column.

**Cause**: Kubernetes cannot find the Docker image. It tried to pull from Docker Hub but the image doesn't exist there.

**Fix**:
```powershell
# Step 1: Make sure the image exists in your local Docker
docker images | Select-String streamshield

# Step 2: Load it into Minikube
minikube image load streamshield-v1:latest
minikube image load streamshield-v2:latest

# Step 3: Verify it's inside Minikube
minikube image ls | Select-String streamshield

# Step 4: Restart the deployment to pick up the image
kubectl rollout restart deployment/streamshield-blue -n streamshield
kubectl rollout restart deployment/streamshield-green -n streamshield
```

> Also verify that `imagePullPolicy: Never` is set in your YAML files.
> This tells Kubernetes to never attempt a remote pull.

---

### ❌ Problem: Pod stuck in "Pending" state

**Symptom**: `kubectl get pods` shows `Pending` for a long time.

**Cause**: Not enough CPU or memory on the Minikube node.

**Fix**:
```powershell
# Check node capacity
kubectl describe node minikube | Select-String -Pattern "cpu|memory|Capacity|Allocatable"

# Restart Minikube with more resources
minikube stop
minikube start --driver=docker --cpus=2 --memory=2048
```

---

### ❌ Problem: Pod not ready (READY shows 0/1)

**Symptom**: Pod STATUS is Running but READY column shows `0/1`.

**Cause**: The readiness probe is failing — `/health` is not returning HTTP 200.

**Fix**:
```powershell
# 1. Check pod events
kubectl describe pod <pod-name> -n streamshield

# 2. Check Flask logs
kubectl logs <pod-name> -n streamshield

# 3. Verify the app is binding to 0.0.0.0 (not 127.0.0.1)
#    In app.py, the last line must be:
#    app.run(host="0.0.0.0", port=5000)
#
#    If Flask only binds to 127.0.0.1, the health probe from Kubernetes
#    will be rejected because it comes from outside the container.
```

---

### ❌ Problem: Service not opening in browser

**Symptom**: `minikube service` command fails or browser doesn't open.

**Fix**:
```powershell
# Get the URL manually
minikube service streamshield-blue-service -n streamshield --url
minikube service streamshield-green-service -n streamshield --url

# Then open the URL manually in your browser
# Example: http://192.168.49.2:30081

# Alternatively, use port-forward as a fallback
kubectl port-forward svc/streamshield-blue-service 8080:80 -n streamshield
# Then open: http://localhost:8080
```

---

### ❌ Problem: CrashLoopBackOff

**Symptom**: Pod keeps restarting, STATUS shows `CrashLoopBackOff`.

**Cause**: The Flask app is crashing on startup.

**Fix**:
```powershell
# Check the crash logs
kubectl logs <pod-name> -n streamshield --previous

# Common causes:
# - Missing Python packages (requirements.txt not installed in Dockerfile)
# - Syntax error in app.py
# - Port conflict inside the container
```

---

## Quick Reference Card

```powershell
# ── Start Everything ───────────────────────────────────────────────────────
minikube start --driver=docker
minikube image load streamshield-v1:latest
minikube image load streamshield-v2:latest
kubectl apply -f k8s\namespace.yaml
kubectl apply -f k8s\blue-deployment.yaml
kubectl apply -f k8s\blue-service.yaml
kubectl apply -f k8s\green-deployment.yaml
kubectl apply -f k8s\green-service.yaml

# ── Check Status ───────────────────────────────────────────────────────────
kubectl get all -n streamshield
kubectl get pods -n streamshield -w          # Watch live updates

# ── Open in Browser ────────────────────────────────────────────────────────
minikube service streamshield-blue-service  -n streamshield   # v1
minikube service streamshield-green-service -n streamshield   # v2

# ── Cleanup ────────────────────────────────────────────────────────────────
kubectl delete namespace streamshield
minikube stop
```

---

## What's Next — Phase 3

Phase 3 will add:
- **Ingress Controller** with Nginx for unified traffic routing
- **Canary traffic splitting** (90% Blue → v1, 10% Green → v2)
- **Prometheus + Grafana** monitoring stack
- **Automated rollback** based on health score thresholds
- **GitHub Actions** CI/CD pipeline for automated build and deploy
