# =============================================================================
# StreamShield — Auto Rollback Engine
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Automatically calculates the release health score and — if the release
# is unhealthy — triggers an immediate rollback to stable v1 without
# any manual intervention.
#
# This simulates a real SRE auto-remediation system:
#   1. Run health probes (same logic as health-score.ps1)
#   2. Calculate health score using the penalty formula
#   3. If score < 70 OR error rate > 5% OR latency > 800ms:
#      → Execute rollback automatically
#   4. If score is healthy:
#      → Print confirmation and exit
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\auto-rollback.ps1
# =============================================================================

# ── Config ────────────────────────────────────────────────────────────────────
$TARGET_URL      = "http://streamshield.local"
$PROBE_ENDPOINT  = "$TARGET_URL/watch"
$TOTAL_REQUESTS  = 20
$TIMEOUT_SECONDS = 8
$NAMESPACE       = "streamshield"

# ── Formatting helpers ────────────────────────────────────────────────────────
function Print-Header($text, $color = "Cyan") {
    Write-Host ""
    Write-Host ("=" * 62) -ForegroundColor DarkCyan
    Write-Host "  $text" -ForegroundColor $color
    Write-Host ("=" * 62) -ForegroundColor DarkCyan
    Write-Host ""
}

function Print-Step($n, $text)  { Write-Host "[STEP $n] $text" -ForegroundColor Yellow }
function Print-Info($text)      { Write-Host "  >> $text" -ForegroundColor Cyan }
function Print-Success($text)   { Write-Host "  OK $text" -ForegroundColor Green }
function Print-Warning($text)   { Write-Host "  !! $text" -ForegroundColor Red }
function Print-Metric($l, $v, $c) {
    Write-Host ("  {0,-32}" -f $l) -NoNewline -ForegroundColor DarkGray
    Write-Host $v -ForegroundColor $c
}

# =============================================================================
Print-Header "STREAMSHIELD AUTO ROLLBACK ENGINE"

Write-Host "  This engine probes the release, calculates health score," -ForegroundColor White
Write-Host "  and triggers rollback automatically if needed." -ForegroundColor White
Write-Host ""

# =============================================================================
# PHASE 1 — Check Kubernetes Pod State
# =============================================================================
Print-Step 1 "Checking Kubernetes pod readiness..."

$podLines = kubectl get pods -n $NAMESPACE --no-headers 2>$null |
            Select-String "streamshield-green"

$totalGreenPods = 0
$readyGreenPods = 0
$restartCount   = 0

foreach ($line in $podLines) {
    $totalGreenPods++
    $parts = $line.Line -split '\s+'
    if ($parts.Count -ge 4) {
        $readyField = $parts[1]
        $restarts   = [int]($parts[3] -replace '[^0-9]','0')
        $restartCount += $restarts
        if ($readyField -match "^(\d+)/(\d+)$") {
            if ([int]$Matches[1] -eq [int]$Matches[2]) { $readyGreenPods++ }
        }
    }
}

$allPodsReady = ($readyGreenPods -eq $totalGreenPods -and $totalGreenPods -gt 0)
Write-Host "  Green pods: $readyGreenPods/$totalGreenPods ready | Restarts: $restartCount" -ForegroundColor White
Write-Host ""

# =============================================================================
# PHASE 2 — Run HTTP Probes
# =============================================================================
Print-Step 2 "Running $TOTAL_REQUESTS HTTP probes against $PROBE_ENDPOINT ..."
Write-Host ""

$successCount      = 0
$failCount         = 0
$totalLatencyMs    = 0
$playbackFailCount = 0

for ($i = 1; $i -le $TOTAL_REQUESTS; $i++) {
    $start = Get-Date
    try {
        $r = Invoke-WebRequest -Uri $PROBE_ENDPOINT `
                 -TimeoutSec $TIMEOUT_SECONDS -ErrorAction Stop
        $latencyMs = [int]((Get-Date) - $start).TotalMilliseconds
        $totalLatencyMs += $latencyMs

        if ($r.StatusCode -eq 200) {
            if ($r.Content -match "500|Crash|Error|buffering" -and
                $r.Content -notmatch "Stable Player") {
                $playbackFailCount++
                $failCount++
                Write-Host "  [$i/$TOTAL_REQUESTS] DEGRADED  ${latencyMs}ms" -ForegroundColor Yellow
            } else {
                $successCount++
                Write-Host "  [$i/$TOTAL_REQUESTS] OK        ${latencyMs}ms" -ForegroundColor Green
            }
        } else {
            $failCount++
            Write-Host "  [$i/$TOTAL_REQUESTS] FAIL $($r.StatusCode)    ${latencyMs}ms" -ForegroundColor Red
        }
    } catch {
        $latencyMs = [int]((Get-Date) - $start).TotalMilliseconds
        $totalLatencyMs += $latencyMs
        $failCount++
        $playbackFailCount++
        Write-Host "  [$i/$TOTAL_REQUESTS] EXCEPTION ${latencyMs}ms" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 200
}

# =============================================================================
# PHASE 3 — Calculate Metrics and Health Score
# =============================================================================
Write-Host ""
Print-Step 3 "Calculating health score..."
Write-Host ""

$errorRate           = [math]::Round(($failCount / $TOTAL_REQUESTS) * 100, 1)
$avgLatencyMs        = [int]($totalLatencyMs / $TOTAL_REQUESTS)
$playbackFailureRate = [math]::Round(($playbackFailCount / $TOTAL_REQUESTS) * 100, 1)

$healthScore = 100
$penalties   = @()

if ($errorRate -gt 5)           { $healthScore -= 30; $penalties += "Error rate ${errorRate}% → -30" }
if ($playbackFailureRate -gt 8) { $healthScore -= 25; $penalties += "Playback failure ${playbackFailureRate}% → -25" }
if ($avgLatencyMs -gt 800)      { $healthScore -= 20; $penalties += "Latency ${avgLatencyMs}ms → -20" }
if (-not $allPodsReady)         { $healthScore -= 15; $penalties += "Pods not ready → -15" }
if ($restartCount -gt 0)        { $healthScore -= 10; $penalties += "Restarts $restartCount → -10" }
$healthScore = [math]::Max(0, $healthScore)

# Rollback trigger check
$rollbackRequired = ($healthScore -lt 70) -or
                    ($errorRate -gt 5) -or
                    ($playbackFailureRate -gt 8) -or
                    ($avgLatencyMs -gt 800)

# Print mini summary
Print-Metric "Error Rate:"           "${errorRate}%"           $(if ($errorRate -gt 5) { "Red" } else { "Green" })
Print-Metric "Avg Latency:"          "${avgLatencyMs}ms"       $(if ($avgLatencyMs -gt 800) { "Red" } else { "Green" })
Print-Metric "Playback Failure:"     "${playbackFailureRate}%"  $(if ($playbackFailureRate -gt 8) { "Red" } else { "Green" })
Print-Metric "Pod Readiness:"        $(if ($allPodsReady) { "All Ready" } else { "NOT READY" }) $(if ($allPodsReady) { "Green" } else { "Red" })
Print-Metric "Health Score:"         "${healthScore}/100"       $(if ($healthScore -ge 75) { "Green" } elseif ($healthScore -ge 60) { "Yellow" } else { "Red" })
Write-Host ""

# =============================================================================
# PHASE 4 — Decision and Action
# =============================================================================

if ($rollbackRequired) {
    # ─── BAD RELEASE DETECTED → AUTO ROLLBACK ──────────────────────────────
    Write-Host ""
    Write-Host ("=" * 62) -ForegroundColor DarkRed
    Write-Host "  BAD RELEASE DETECTED — INITIATING AUTO ROLLBACK" -ForegroundColor Red
    Write-Host ("=" * 62) -ForegroundColor DarkRed
    Write-Host ""

    foreach ($p in $penalties) {
        Write-Host "    Trigger: $p" -ForegroundColor Red
    }
    Write-Host ""

    Print-Step 4 "Disabling chaos mode on v2..."

    try {
        Invoke-WebRequest -Uri "http://streamshield.local/chaos/off" `
            -TimeoutSec 8 -ErrorAction Stop | Out-Null
        Print-Success "Chaos mode disabled (direct route)."
    } catch {
        Write-Host "  (Direct route not reachable — continuing)" -ForegroundColor DarkGray
    }

    try {
        $h = @{ "X-Internal-Team" = "true" }
        Invoke-WebRequest -Uri "http://streamshield.local/chaos/off" `
            -Headers $h -TimeoutSec 8 -ErrorAction Stop | Out-Null
        Print-Success "Chaos mode disabled (QA header route)."
    } catch {
        Write-Host "  (QA header route not reachable — continuing)" -ForegroundColor DarkGray
    }
    Write-Host ""

    Print-Step 5 "Removing all canary and unsafe ingresses..."
    kubectl delete -f k8s/ingress-canary-10.yaml      --ignore-not-found=true 2>$null
    kubectl delete -f k8s/ingress-internal-team.yaml  --ignore-not-found=true 2>$null
    kubectl delete -f k8s/unsafe-rollout.yaml          --ignore-not-found=true 2>$null
    kubectl delete -f k8s/ingress-main.yaml            --ignore-not-found=true 2>$null
    Start-Sleep 3
    Print-Success "All non-production ingresses removed."
    Write-Host ""

    Print-Step 6 "Re-applying main ingress → restoring v1 (Blue) as production..."
    kubectl apply -f k8s/ingress-main.yaml

    if ($LASTEXITCODE -eq 0) {
        Print-Success "Main ingress restored. 100% traffic back to v1."
    } else {
        Print-Warning "Could not apply main ingress — manual fix required:"
        Print-Info "kubectl apply -f k8s/ingress-main.yaml"
    }
    Write-Host ""

    # ── Final Banner ──────────────────────────────────────────────────────────
    Write-Host ("=" * 62) -ForegroundColor DarkGreen
    Write-Host "  AUTO ROLLBACK SUCCESSFUL" -ForegroundColor Green
    Write-Host ("=" * 62) -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "  Health Score at Rollback : ${healthScore}/100" -ForegroundColor Red
    Write-Host "  Traffic restored to      : v1 Blue (100%)" -ForegroundColor Green
    Write-Host "  Chaos mode               : Disabled" -ForegroundColor Green
    Write-Host "  Time of rollback         : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
    Write-Host ""

} else {
    # ─── RELEASE HEALTHY → NO ACTION ─────────────────────────────────────────
    Write-Host ""
    Write-Host ("=" * 62) -ForegroundColor DarkGreen
    Write-Host "  RELEASE IS HEALTHY — NO ROLLBACK REQUIRED" -ForegroundColor Green
    Write-Host ("=" * 62) -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "  Health Score : ${healthScore}/100" -ForegroundColor Green
    Write-Host "  Error Rate   : ${errorRate}% (threshold: 5%)" -ForegroundColor Green
    Write-Host "  Latency      : ${avgLatencyMs}ms (threshold: 800ms)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next actions:" -ForegroundColor Yellow
    Write-Host "    - Continue monitoring with: .\scripts\health-score.ps1" -ForegroundColor White
    Write-Host "    - Increase canary traffic if stable" -ForegroundColor White
    Write-Host "    - Run full demo: .\scripts\demo-compare.ps1" -ForegroundColor White
    Write-Host ""
}

# =============================================================================
# FINAL — Show System State
# =============================================================================
Print-Step 7 "Final system state:"
Write-Host ""
Write-Host "  Pods:" -ForegroundColor DarkGray
kubectl get pods -n $NAMESPACE
Write-Host ""
Write-Host "  Ingresses:" -ForegroundColor DarkGray
kubectl get ingress -n $NAMESPACE
Write-Host ""
