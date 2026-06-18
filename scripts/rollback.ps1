$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================="
Write-Host " StreamShield Rollback Simulation"
Write-Host "========================================="
Write-Host ""

Write-Host "[INFO] This script simulates rollback to stable Blue version."
Write-Host "[INFO] Rollback is used when Green release is unhealthy."
Write-Host ""

Write-Host "[CHECK] Checking Kubernetes namespace..."
kubectl get ns streamshield | Out-Null
Write-Host "[OK] Namespace streamshield found."
Write-Host ""

Write-Host "[BEFORE] Current pods:"
kubectl get pods -n streamshield
Write-Host ""

Write-Host "[BEFORE] Current ingress:"
kubectl get ingress -n streamshield
Write-Host ""

Write-Host "[STEP 1] Ensuring Blue stable deployment is available..."
kubectl apply -f k8s/blue-deployment.yaml
kubectl apply -f k8s/blue-service.yaml
Write-Host "[OK] Blue stable environment verified."
Write-Host ""

Write-Host "[STEP 2] Removing canary routing to Green if present..."

if (Test-Path "k8s/ingress-canary-10.yaml") {
    kubectl delete -f k8s/ingress-canary-10.yaml --ignore-not-found
    Write-Host "[OK] Canary ingress removed or already absent."
}
else {
    kubectl delete ingress streamshield-canary-ingress -n streamshield --ignore-not-found
    Write-Host "[OK] Canary ingress removed by name or already absent."
}

Write-Host ""

Write-Host "[STEP 3] Applying main Blue routing if available..."

if (Test-Path "k8s/ingress-main.yaml") {
    kubectl apply -f k8s/ingress-main.yaml
    Write-Host "[OK] Main ingress applied."
}
else {
    Write-Host "[WARN] k8s/ingress-main.yaml not found. Skipping main ingress apply."
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
Write-Host " Rollback Completed"
Write-Host "========================================="
Write-Host ""
Write-Host "Rollback Result:"
Write-Host "- Stable Blue version remains available."
Write-Host "- Canary traffic to Green is removed."
Write-Host "- Traffic is restored to the safe Blue path."
Write-Host "- Users are protected from unhealthy Green release."
Write-Host ""
Write-Host "Explanation:"
Write-Host "- Rollback means returning traffic to the stable version."
Write-Host "- In our project, Blue is stable and Green is the new release."
Write-Host "- If Green fails, rollback protects users by keeping Blue active."
Write-Host ""
