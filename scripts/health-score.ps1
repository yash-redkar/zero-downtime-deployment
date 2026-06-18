$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================="
Write-Host " StreamShield Health Score Check"
Write-Host "========================================="
Write-Host ""

Write-Host "[INFO] This script simulates release health validation."
Write-Host "[INFO] Health score is used to decide rollout or rollback."
Write-Host ""

Write-Host "[CHECK] Checking Kubernetes namespace..."
kubectl get ns streamshield | Out-Null
Write-Host "[OK] Namespace streamshield found."
Write-Host ""

Write-Host "[CHECK] Checking Blue, Green, and PostgreSQL pods..."
kubectl get pods -n streamshield
Write-Host ""

Write-Host "[SIMULATION] Collecting release metrics..."
Start-Sleep -Seconds 1

$totalRequests = 20
$successRequests = 19
$failedRequests = 1
$errorRate = 5
$averageLatencyMs = 120
$availability = 95
$podRestartRisk = 0

Write-Host "Total Requests     : $totalRequests"
Write-Host "Success Requests   : $successRequests"
Write-Host "Failed Requests    : $failedRequests"
Write-Host "Error Rate         : $errorRate percent"
Write-Host "Average Latency    : $averageLatencyMs ms"
Write-Host "Availability       : $availability percent"
Write-Host "Pod Restart Risk   : $podRestartRisk"
Write-Host ""

$healthScore = 100

if ($errorRate -ge 5) {
    $healthScore -= 10
}

if ($averageLatencyMs -gt 300) {
    $healthScore -= 10
}

if ($availability -lt 95) {
    $healthScore -= 10
}

if ($podRestartRisk -gt 0) {
    $healthScore -= 10
}

Write-Host "========================================="
Write-Host " Health Score Result"
Write-Host "========================================="
Write-Host ""

Write-Host "Final Health Score : $healthScore / 100"
Write-Host ""

if ($healthScore -ge 90) {
    Write-Host "[DECISION] Release is HEALTHY." -ForegroundColor Green
    Write-Host "[ACTION] Continue rollout / allow canary traffic." -ForegroundColor Green
}
elseif ($healthScore -ge 70) {
    Write-Host "[DECISION] Release is RISKY." -ForegroundColor Yellow
    Write-Host "[ACTION] Keep monitoring before promotion." -ForegroundColor Yellow
}
else {
    Write-Host "[DECISION] Release is UNHEALTHY." -ForegroundColor Red
    Write-Host "[ACTION] Rollback recommended." -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================="
Write-Host " Health Score Check Completed"
Write-Host "========================================="
Write-Host ""
Write-Host "Explanation:"
Write-Host "- Good health score means rollout can continue."
Write-Host "- Bad health score means rollback should happen."
Write-Host "- In real production, these metrics come from Prometheus and Grafana."
Write-Host ""
