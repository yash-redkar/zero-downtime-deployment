# =============================================================================
# StreamShield — Manual Rollback Script
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Performs a manual, controlled rollback of the StreamShield platform:
#   1. Disables chaos mode on v2
#   2. Removes all canary/unsafe/internal ingresses
#   3. Ensures the main ingress routes traffic back to stable v1 (Blue)
#   4. Optionally scales down green deployment to 1 replica
#   5. Verifies the final cluster state
#
# Use this when:
#   - Health score shows ROLLBACK REQUIRED
#   - You want to manually reset after a bad release demo
#   - auto-rollback.ps1 could not complete due to network issues
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\rollback.ps1
# =============================================================================

# ── Formatting helpers ────────────────────────────────────────────────────────
function Print-Header($text) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkRed
    Write-Host "  $text" -ForegroundColor Red
    Write-Host ("=" * 60) -ForegroundColor DarkRed
    Write-Host ""
}

function Print-Step($n, $text) {
    Write-Host "[STEP $n] " -ForegroundColor Yellow -NoNewline
    Write-Host $text -ForegroundColor White
}

function Print-Info($text)    { Write-Host "  >> $text" -ForegroundColor Cyan }
function Print-Success($text) { Write-Host "  OK $text" -ForegroundColor Green }
function Print-Warning($text) { Write-Host "  !! $text" -ForegroundColor Yellow }

# =============================================================================
Print-Header "STREAMSHIELD MANUAL ROLLBACK"

Write-Host "  Initiating controlled rollback to v1 (Blue)..." -ForegroundColor White
Write-Host "  This will restore 100% of traffic to stable v1." -ForegroundColor White
Write-Host ""

# =============================================================================
# STEP 1 — Disable Chaos Mode (Direct Route)
# =============================================================================
Print-Step 1 "Disabling chaos mode on v2 (direct URL)..."
Print-Info "Sending GET http://streamshield.local/chaos/off"

try {
    $r = Invoke-WebRequest -Uri "http://streamshield.local/chaos/off" `
             -TimeoutSec 8 -ErrorAction Stop
    Print-Success "Chaos mode disabled. Response: $($r.StatusCode)"
} catch {
    Print-Warning "Direct /chaos/off failed — ingress may already be removed."
}
Write-Host ""

# =============================================================================
# STEP 2 — Disable Chaos Mode (via QA Header Route)
# =============================================================================
Print-Step 2 "Disabling chaos mode via internal QA header..."
Print-Info "Sending GET http://streamshield.local/chaos/off with X-Internal-Team: true"

try {
    $headers = @{ "X-Internal-Team" = "true" }
    $r = Invoke-WebRequest -Uri "http://streamshield.local/chaos/off" `
             -Headers $headers -TimeoutSec 8 -ErrorAction Stop
    Print-Success "Chaos mode disabled via QA header. Response: $($r.StatusCode)"
} catch {
    Print-Warning "QA header /chaos/off failed — internal ingress may be removed."
}
Write-Host ""

# =============================================================================
# STEP 3 — Remove All Unsafe/Canary/Internal Ingresses
# =============================================================================
Print-Step 3 "Removing all non-production ingress rules..."
Print-Info "Using --ignore-not-found=true — safe to run even if resources don't exist."
Write-Host ""

Write-Host "  Removing: unsafe-rollout ingress..." -ForegroundColor DarkGray
kubectl delete -f k8s/unsafe-rollout.yaml --ignore-not-found=true

Write-Host "  Removing: canary-10 ingress..." -ForegroundColor DarkGray
kubectl delete -f k8s/ingress-canary-10.yaml --ignore-not-found=true

Write-Host "  Removing: internal-team ingress..." -ForegroundColor DarkGray
kubectl delete -f k8s/ingress-internal-team.yaml --ignore-not-found=true

Write-Host "  Removing: main ingress (will be re-applied clean)..." -ForegroundColor DarkGray
kubectl delete -f k8s/ingress-main.yaml --ignore-not-found=true

Start-Sleep 3
Print-Success "All rollout ingresses removed."
Write-Host ""

# =============================================================================
# STEP 4 — Re-apply Main Production Ingress (v1 as Primary)
# =============================================================================
Print-Step 4 "Re-applying main ingress → routing ALL traffic back to v1 (Blue)..."
Print-Info "Applying k8s/ingress-main.yaml"

kubectl apply -f k8s/ingress-main.yaml

if ($LASTEXITCODE -eq 0) {
    Print-Success "Main ingress applied. v1 (Blue) is now the sole production route."
} else {
    Print-Warning "Could not apply main ingress!"
    Print-Info "Manual fix: kubectl apply -f k8s/ingress-main.yaml"
}
Write-Host ""

# =============================================================================
# STEP 5 — Scale Down Green Deployment (Optional Safety Measure)
# =============================================================================
Print-Step 5 "Scaling green deployment to 1 replica (resource conservation)..."
Print-Info "This reduces green resource usage while v2 is not in active use."
Print-Info "Command: kubectl scale deployment streamshield-green --replicas=1 -n streamshield"

kubectl scale deployment streamshield-green --replicas=1 -n streamshield

if ($LASTEXITCODE -eq 0) {
    Print-Success "Green deployment scaled to 1 replica."
} else {
    Print-Warning "Could not scale green deployment. It may still be at 2 replicas."
}
Write-Host ""

# =============================================================================
# STEP 6 — Verify Final Cluster State
# =============================================================================
Print-Step 6 "Verifying final cluster state..."
Write-Host ""

Write-Host "  Current Ingress Resources:" -ForegroundColor DarkGray
kubectl get ingress -n streamshield
Write-Host ""

Write-Host "  Current Pods:" -ForegroundColor DarkGray
kubectl get pods -n streamshield
Write-Host ""

# =============================================================================
# DONE
# =============================================================================
Write-Host ("=" * 60) -ForegroundColor DarkCyan
Write-Host "  ROLLBACK COMPLETE" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Traffic restored to stable v1 (Blue environment)." -ForegroundColor Green
Write-Host "  Chaos mode is OFF." -ForegroundColor Green
Write-Host "  Green deployment is at 1 replica (idle)." -ForegroundColor Green
Write-Host ""
Write-Host "  Verify by visiting: http://streamshield.local" -ForegroundColor Cyan
Write-Host "  Should show: StreamShield v1 — Stable Blue" -ForegroundColor DarkGray
Write-Host ""
