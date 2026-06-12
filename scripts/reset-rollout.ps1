# =============================================================================
# StreamShield — Reset Rollout Environment
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Resets the cluster to a clean state after running either rollout mode:
#   1. Disables chaos mode on v2 (via both direct and QA-header routes)
#   2. Removes all rollout ingress resources
#   3. Re-applies the main ingress pointing to stable v1 (Blue)
#   4. Confirms the reset is complete
#
# This script is safe to run at any time — all delete commands use
# --ignore-not-found=true so they will not fail if resources don't exist.
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\reset-rollout.ps1
# =============================================================================

# ── Formatting helpers ────────────────────────────────────────────────────────
function Print-Header($text) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ""
}

function Print-Step($step, $text) {
    Write-Host "[STEP $step] " -ForegroundColor Yellow -NoNewline
    Write-Host $text -ForegroundColor White
}

function Print-Info($text) {
    Write-Host "  >> $text" -ForegroundColor Cyan
}

function Print-Success($text) {
    Write-Host "  OK $text" -ForegroundColor Green
}

function Print-Warning($text) {
    Write-Host "  !! $text" -ForegroundColor Yellow
}

# =============================================================================
# STEP 0 — Title
# =============================================================================
Print-Header "STREAMSHIELD ROLLOUT RESET"

Write-Host "  Resetting the cluster to stable state." -ForegroundColor White
Write-Host "  Traffic will be restored to v1 (Blue) after this script." -ForegroundColor White
Write-Host ""

# =============================================================================
# STEP 1 — Disable Chaos Mode on v2 (Direct Route)
# =============================================================================
Print-Step 1 "Disabling chaos mode on v2 (direct URL attempt)..."
Print-Info "Attempting: GET http://streamshield.local/chaos/off"

try {
    $r = Invoke-WebRequest -Uri "http://streamshield.local/chaos/off" `
             -TimeoutSec 10 -ErrorAction Stop
    Print-Success "Chaos mode disabled via direct route. ($($r.StatusCode))"
} catch {
    Print-Warning "Direct route not reachable (ingress may already be removed). Continuing..."
}
Write-Host ""

# =============================================================================
# STEP 2 — Disable Chaos Mode on v2 (via Internal QA Header)
# =============================================================================
Print-Step 2 "Disabling chaos mode via internal QA header route..."
Print-Info "Attempting: GET http://streamshield.local/chaos/off with X-Internal-Team: true"

try {
    $headers = @{ "X-Internal-Team" = "true" }
    $r = Invoke-WebRequest -Uri "http://streamshield.local/chaos/off" `
             -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    Print-Success "Chaos mode disabled via QA header route. ($($r.StatusCode))"
} catch {
    Print-Warning "QA header route not reachable. This is expected if ingress is down."
    Print-Info "Chaos mode will reset automatically when v2 pod restarts."
}
Write-Host ""

# =============================================================================
# STEP 3 — Remove All Rollout Ingresses
# =============================================================================
Print-Step 3 "Removing all rollout ingress resources..."
Print-Info "Using --ignore-not-found=true — safe if resources don't exist."
Write-Host ""

Write-Host "  Deleting unsafe-rollout ingress..." -ForegroundColor DarkGray
kubectl delete -f k8s/unsafe-rollout.yaml --ignore-not-found=true

Write-Host "  Deleting canary-10 ingress..." -ForegroundColor DarkGray
kubectl delete -f k8s/ingress-canary-10.yaml --ignore-not-found=true

Write-Host "  Deleting internal-team ingress..." -ForegroundColor DarkGray
kubectl delete -f k8s/ingress-internal-team.yaml --ignore-not-found=true

Write-Host "  Deleting main ingress (will be re-applied clean)..." -ForegroundColor DarkGray
kubectl delete -f k8s/ingress-main.yaml --ignore-not-found=true

Start-Sleep 3
Print-Success "All rollout ingresses removed."
Write-Host ""

# =============================================================================
# STEP 4 — Re-apply Clean Main Ingress Pointing to v1
# =============================================================================
Print-Step 4 "Re-applying main ingress → routing traffic back to v1 (Blue)..."
Print-Info "This restores stable production routing to streamshield-blue-service."

kubectl apply -f k8s/ingress-main.yaml

if ($LASTEXITCODE -eq 0) {
    Print-Success "Main ingress re-applied. Traffic is back to v1 (Blue)."
} else {
    Print-Warning "Could not apply main ingress. You may need to re-apply manually:"
    Print-Info "kubectl apply -f k8s/ingress-main.yaml"
}
Write-Host ""

# =============================================================================
# STEP 5 — Confirm Current State
# =============================================================================
Print-Step 5 "Current ingress state:"
Write-Host ""
kubectl get ingress -n streamshield
Write-Host ""

Print-Step 6 "Current pods (all should be Running):"
Write-Host ""
kubectl get pods -n streamshield
Write-Host ""

# =============================================================================
# DONE
# =============================================================================
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host "  RESET COMPLETE" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Traffic is back to stable v1 (Blue environment)." -ForegroundColor Green
Write-Host "  Chaos mode is OFF on v2." -ForegroundColor Green
Write-Host "  Only ingress-main.yaml is active." -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    Run Unsafe Mode : .\scripts\unsafe-rollout.ps1" -ForegroundColor White
Write-Host "    Run Smart Mode  : .\scripts\smart-rollout.ps1" -ForegroundColor White
Write-Host ""
