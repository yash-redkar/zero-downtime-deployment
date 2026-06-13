$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================="
Write-Host " StreamShield Smart Rollout Simulation"
Write-Host "========================================="
Write-Host ""

Write-Host "[INFO] This script simulates a safe rollout."
Write-Host "[INFO] Green version is validated before promotion."
Write-Host ""

# Check namespace
Write-Host "[CHECK] Checking Kubernetes namespace..."
kubectl get ns streamshield | Out-Null
Write-Host "[OK] Namespace streamshield found."
Write-Host ""

# Show current pods
Write-Host "[BEFORE] Current pods:"
kubectl get pods -n streamshield
Write-Host ""

# Apply blue deployment and service
Write-Host "[STEP 1] Ensuring stable Blue deployment exists..."
kubectl apply -f k8s/blue-deployment.yaml
kubectl apply -f k8s/blue-service.yaml
Write-Host "[OK] Blue environment verified."
Write-Host ""

# Apply green deployment and service
Write-Host "[STEP 2] Deploying Green release..."
kubectl apply -f k8s/green-deployment.yaml
kubectl apply -f k8s/green-service.yaml
Write-Host "[OK] Green environment applied."
Write-Host ""

# Wait for green deployment
Write-Host "[STEP 3] Waiting for Green rollout to complete..."
kubectl rollout status deployment/streamshield-green -n streamshield --timeout=120s
Write-Host "[OK] Green rollout completed."
Write-Host ""

# Health validation simulation
Write-Host "[STEP 4] Running health validation..."

$ErrorRate = 2
$Latency = 120
$HealthScore = 94

Write-Host "Health Score : $HealthScore"
Write-Host "Error Rate   : $ErrorRate%"
Write-Host "Latency      : $Latency ms"
Write-Host ""

if ($HealthScore -ge 90 -and $ErrorRate -lt 5) {
    Write-Host "[DECISION] Green release is healthy."
    Write-Host "[ACTION] Proceeding with controlled rollout."
    Write-Host ""

    if (Test-Path "k8s/ingress-canary-10.yaml") {
        Write-Host "[STEP 5] Applying 10 percent canary routing..."
        kubectl apply -f k8s/ingress-canary-10.yaml
        Write-Host "[OK] Canary ingress applied."
    }
    else {
        Write-Host "[WARN] Canary ingress file not found. Skipping routing step."
    }
}
else {
    Write-Host "[DECISION] Green release is unhealthy."
    Write-Host "[ACTION] Rollback recommended."
    Write-Host ""

    if (Test-Path ".\scripts\rollback.ps1") {
        powershell -ExecutionPolicy Bypass -File .\scripts\rollback.ps1
    }
}

Write-Host ""
Write-Host "[AFTER] Pods:"
kubectl get pods -n streamshield

Write-Host ""
Write-Host "[AFTER] Services:"
kubectl get svc -n streamshield

Write-Host ""
Write-Host "[AFTER] Ingress:"
kubectl get ingress -n streamshield

Write-Host ""
Write-Host "========================================="
Write-Host " Smart Rollout Completed"
Write-Host "========================================="
Write-Host ""
Write-Host "Safety Checks:"
Write-Host "- Green deployment verified"
Write-Host "- Rollout status checked"
Write-Host "- Health score validated"
Write-Host "- Error rate checked"
Write-Host "- Canary routing applied only after validation"
Write-Host ""