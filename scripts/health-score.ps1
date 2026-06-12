# =============================================================================
# StreamShield — Health Score Engine
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Calculates a health score (0-100) for the currently deployed v2 release
# by running real HTTP probe tests and checking Kubernetes pod state.
#
# Health Score Formula:
#   Start at 100. Apply penalties:
#   - Error Rate > 5%       → -30 points
#   - Playback Failure > 8% → -25 points
#   - Latency > 800ms       → -20 points
#   - Pod not ready         → -15 points
#   - Restarts > 0          → -10 points
#
# Decision bands:
#   90-100 = Excellent
#   75-89  = Healthy
#   60-74  = Risky
#   <60    = Rollback Required
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\health-score.ps1
# =============================================================================

# ── Config ────────────────────────────────────────────────────────────────────
$TARGET_URL       = "http://streamshield.local"
$PROBE_ENDPOINT   = "$TARGET_URL/watch"
$HEALTH_ENDPOINT  = "$TARGET_URL/health"
$TOTAL_REQUESTS   = 20
$TIMEOUT_SECONDS  = 8
$NAMESPACE        = "streamshield"

# ── Formatting helpers ────────────────────────────────────────────────────────
function Print-Header($text) {
    Write-Host ""
    Write-Host ("=" * 62) -ForegroundColor DarkCyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ("=" * 62) -ForegroundColor DarkCyan
    Write-Host ""
}

function Print-Section($text) {
    Write-Host ""
    Write-Host "  ── $text" -ForegroundColor Yellow
    Write-Host ""
}

function Print-Metric($label, $value, $color) {
    Write-Host ("  {0,-30}" -f $label) -NoNewline -ForegroundColor DarkGray
    Write-Host $value -ForegroundColor $color
}

# =============================================================================
Print-Header "STREAMSHIELD HEALTH SCORE ENGINE"
Write-Host "  Target: $TARGET_URL" -ForegroundColor DarkGray
Write-Host "  Probing: $PROBE_ENDPOINT ($TOTAL_REQUESTS requests)" -ForegroundColor DarkGray
Write-Host ""

# =============================================================================
# SECTION 1 — Kubernetes Pod Status
# =============================================================================
Print-Section "Kubernetes Pod Status"

Write-Host "  Checking pod status in namespace: $NAMESPACE" -ForegroundColor DarkGray
Write-Host ""

kubectl get pods -n $NAMESPACE
Write-Host ""

# Check green deployment readiness
Write-Host "  Green deployment readiness:" -ForegroundColor DarkGray
$greenDeployment = kubectl get deployment streamshield-green -n $NAMESPACE `
                       --no-headers 2>$null
Write-Host "  $greenDeployment" -ForegroundColor White

# Count ready pods for green
$podLines = kubectl get pods -n $NAMESPACE --no-headers 2>$null |
            Select-String "streamshield-green"

$totalGreenPods = 0
$readyGreenPods = 0
$restartCount   = 0

foreach ($line in $podLines) {
    $totalGreenPods++
    $parts = $line.Line -split '\s+'
    # Column format: NAME  READY  STATUS  RESTARTS  AGE
    if ($parts.Count -ge 4) {
        $readyField = $parts[1]   # e.g. "1/1" or "0/1"
        $restarts   = [int]($parts[3] -replace '[^0-9]','0')
        $restartCount += $restarts

        if ($readyField -match "^(\d+)/(\d+)$") {
            if ([int]$Matches[1] -eq [int]$Matches[2]) {
                $readyGreenPods++
            }
        }
    }
}

$allPodsReady = ($readyGreenPods -eq $totalGreenPods -and $totalGreenPods -gt 0)
$podReadyText = if ($allPodsReady) { "All Ready ($readyGreenPods/$totalGreenPods)" } `
                else { "NOT READY ($readyGreenPods/$totalGreenPods)" }

Write-Host ""
Write-Host "  Green pods: $podReadyText  |  Total restarts: $restartCount" -ForegroundColor White

# =============================================================================
# SECTION 2 — HTTP Probe Tests (Simulating Streaming Viewers)
# =============================================================================
Print-Section "HTTP Probe Tests — Simulating Streaming Viewers"

Write-Host "  Running $TOTAL_REQUESTS requests to $PROBE_ENDPOINT ..." -ForegroundColor DarkGray
Write-Host ""

$successCount      = 0
$failCount         = 0
$totalLatencyMs    = 0
$playbackFailCount = 0

for ($i = 1; $i -le $TOTAL_REQUESTS; $i++) {
    $start = Get-Date

    try {
        $response = Invoke-WebRequest -Uri $PROBE_ENDPOINT `
                        -TimeoutSec $TIMEOUT_SECONDS -ErrorAction Stop

        $latencyMs = [int]((Get-Date) - $start).TotalMilliseconds
        $totalLatencyMs += $latencyMs

        if ($response.StatusCode -eq 200) {
            # Check if the response body indicates a degraded/failure state
            # The v2 watch page shows specific text when chaos is active
            if ($response.Content -match "500|Crash|Error|buffering" -and
                $response.Content -notmatch "Stable Player") {
                $playbackFailCount++
                $failCount++
                Write-Host "  [Request $i] 200 but DEGRADED  | ${latencyMs}ms" -ForegroundColor Yellow
            } else {
                $successCount++
                Write-Host "  [Request $i] OK  200           | ${latencyMs}ms" -ForegroundColor Green
            }
        } else {
            $failCount++
            Write-Host "  [Request $i] FAIL $($response.StatusCode)         | ${latencyMs}ms" -ForegroundColor Red
        }

    } catch {
        $latencyMs = [int]((Get-Date) - $start).TotalMilliseconds
        $totalLatencyMs += $latencyMs
        $failCount++
        $playbackFailCount++

        $errMsg = $_.Exception.Message
        if ($errMsg.Length -gt 50) { $errMsg = $errMsg.Substring(0,50) + "..." }
        Write-Host "  [Request $i] EXCEPTION          | ${latencyMs}ms | $errMsg" -ForegroundColor Red
    }

    # Small pause between requests to simulate real viewer behaviour
    Start-Sleep -Milliseconds 200
}

# =============================================================================
# SECTION 3 — Calculate Metrics
# =============================================================================
Print-Section "Calculating Metrics"

$errorRate           = if ($TOTAL_REQUESTS -gt 0) { [math]::Round(($failCount / $TOTAL_REQUESTS) * 100, 1) } else { 0 }
$avgLatencyMs        = if ($TOTAL_REQUESTS -gt 0) { [int]($totalLatencyMs / $TOTAL_REQUESTS) } else { 0 }
$playbackFailureRate = if ($TOTAL_REQUESTS -gt 0) { [math]::Round(($playbackFailCount / $TOTAL_REQUESTS) * 100, 1) } else { 0 }

# =============================================================================
# SECTION 4 — Calculate Health Score
# =============================================================================
$healthScore = 100
$penalties   = @()

# Penalty: Error Rate
if ($errorRate -gt 5) {
    $healthScore -= 30
    $penalties += "Error Rate ${errorRate}% > 5%  → -30"
}

# Penalty: Playback Failure Rate
if ($playbackFailureRate -gt 8) {
    $healthScore -= 25
    $penalties += "Playback Failure ${playbackFailureRate}% > 8%  → -25"
}

# Penalty: Average Latency
if ($avgLatencyMs -gt 800) {
    $healthScore -= 20
    $penalties += "Avg Latency ${avgLatencyMs}ms > 800ms  → -20"
}

# Penalty: Pod Readiness
if (-not $allPodsReady) {
    $healthScore -= 15
    $penalties += "Pod not ready ($readyGreenPods/$totalGreenPods)  → -15"
}

# Penalty: Restarts
if ($restartCount -gt 0) {
    $healthScore -= 10
    $penalties += "Restart count $restartCount > 0  → -10"
}

# Clamp minimum to 0
$healthScore = [math]::Max(0, $healthScore)

# Determine decision band
if ($healthScore -ge 90)     { $decision = "EXCELLENT";           $decisionColor = "Green"  }
elseif ($healthScore -ge 75) { $decision = "HEALTHY";             $decisionColor = "Green"  }
elseif ($healthScore -ge 60) { $decision = "RISKY";               $decisionColor = "Yellow" }
else                          { $decision = "ROLLBACK REQUIRED";   $decisionColor = "Red"    }

# Rollback required condition
$rollbackRequired = ($healthScore -lt 70) -or
                    ($errorRate -gt 5) -or
                    ($playbackFailureRate -gt 8) -or
                    ($avgLatencyMs -gt 800)

# =============================================================================
# SECTION 5 — Print Health Score Report
# =============================================================================
Write-Host ""
Write-Host ("=" * 62) -ForegroundColor DarkCyan
Write-Host "  STREAMSHIELD HEALTH SCORE REPORT" -ForegroundColor Cyan
Write-Host ("=" * 62) -ForegroundColor DarkCyan
Write-Host ""

Print-Metric "Active Release:"         "v2 (Green — Canary)"         "White"
Print-Metric "Total Requests:"         "$TOTAL_REQUESTS"              "White"
Print-Metric "Successful Requests:"    "$successCount"                "Green"
Print-Metric "Failed Requests:"        "$failCount"                   $(if ($failCount -gt 0) { "Red" } else { "Green" })
Print-Metric "Error Rate:"             "${errorRate}%"                $(if ($errorRate -gt 5) { "Red" } else { "Green" })
Print-Metric "Average Latency:"        "${avgLatencyMs}ms"            $(if ($avgLatencyMs -gt 800) { "Red" } elseif ($avgLatencyMs -gt 500) { "Yellow" } else { "Green" })
Print-Metric "Playback Failure Rate:"  "${playbackFailureRate}%"      $(if ($playbackFailureRate -gt 8) { "Red" } else { "Green" })
Print-Metric "Pod Readiness:"          $podReadyText                  $(if ($allPodsReady) { "Green" } else { "Red" })
Print-Metric "Pod Restart Count:"      "$restartCount"                $(if ($restartCount -gt 0) { "Yellow" } else { "Green" })

Write-Host ""
Write-Host "  Penalties Applied:" -ForegroundColor DarkGray
if ($penalties.Count -eq 0) {
    Write-Host "    None — all metrics within thresholds" -ForegroundColor Green
} else {
    foreach ($p in $penalties) {
        Write-Host "    - $p" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host ("  {0,-30}" -f "Health Score:") -NoNewline -ForegroundColor White
Write-Host "${healthScore}/100" -ForegroundColor $(if ($healthScore -ge 75) { "Green" } elseif ($healthScore -ge 60) { "Yellow" } else { "Red" })

Write-Host ("  {0,-30}" -f "Decision:") -NoNewline -ForegroundColor White
Write-Host $decision -ForegroundColor $decisionColor

Write-Host ""
Write-Host ("=" * 62) -ForegroundColor DarkCyan

# =============================================================================
# SECTION 6 — Rollback Recommendation
# =============================================================================
if ($rollbackRequired) {
    Write-Host ""
    Write-Host "  ⚠️  ROLLBACK RECOMMENDED" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Reason:" -ForegroundColor DarkGray
    if ($errorRate -gt 5)           { Write-Host "    - Error rate ${errorRate}% exceeds 5% threshold" -ForegroundColor Red }
    if ($playbackFailureRate -gt 8) { Write-Host "    - Playback failure rate ${playbackFailureRate}% exceeds 8% threshold" -ForegroundColor Red }
    if ($avgLatencyMs -gt 800)      { Write-Host "    - Latency ${avgLatencyMs}ms exceeds 800ms threshold" -ForegroundColor Red }
    if ($healthScore -lt 70)        { Write-Host "    - Health score ${healthScore} is below rollback threshold (70)" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Options:" -ForegroundColor Yellow
    Write-Host "    Auto Rollback : .\scripts\auto-rollback.ps1" -ForegroundColor Cyan
    Write-Host "    Manual        : .\scripts\rollback.ps1" -ForegroundColor Cyan
    Write-Host "    Reset Demo    : .\scripts\reset-rollout.ps1" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "  ✅  Release is healthy. No rollback required." -ForegroundColor Green
    Write-Host "      Continue monitoring or increase canary traffic." -ForegroundColor DarkGray
}

Write-Host ""
