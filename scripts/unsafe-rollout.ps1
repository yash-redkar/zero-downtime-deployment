$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================="
Write-Host " StreamShield Unsafe Rollout Simulation"
Write-Host "========================================="
Write-Host ""

Write-Host "[INFO] This script simulates an unsafe rollout."
Write-Host "[INFO] Green version is promoted without health-score validation."
Write-Host ""

# Check kubectl
Write-Host "[CHECK] Checking kubectl access..."
kubectl get ns streamshield | Out-Null

Write-Host "[OK] Kubernetes namespace streamshield found."
Write-Host ""

# Show current pods
Write-Host "[BEFORE] Current pods:"
kubectl get pods -n streamshield
Write-Host ""

# Apply green deployment and service
Write-Host "[STEP] Applying Green deployment..."
kubectl apply -f k8s/green-deployment.yaml

Write-Host "[STEP] Applying Green service..."
kubectl apply -f k8s/green-service.yaml

Write-Host ""

# Apply canary ingress if available
if (Test-Path "k8s/ingress-canary-10.yaml") {
    Write-Host "[STEP] Applying unsafe canary routing..."
    kubectl apply -f k8s/ingress-canary-10.yaml
}
else {
    Write-Host "[WARN] k8s/ingress-canary-10.yaml not found. Skipping canary ingress."
}

Write-Host ""

# Verification
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
Write-Host " Unsafe Rollout Completed"
Write-Host "========================================="
Write-Host ""
Write-Host "Risk:"
Write-Host "- No health score check"
Write-Host "- No error-rate validation"
Write-Host "- No automatic rollback decision"
Write-Host "- Green version can receive traffic before verification"
Write-Host ""