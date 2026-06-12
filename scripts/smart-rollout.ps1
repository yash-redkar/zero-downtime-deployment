# =============================================================================
# StreamShield — Smart Rollout Mode Simulator
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Simulates a safe, professional DevOps release strategy:
#   - v1 (Blue) stays as the stable production environment for most users
#   - Internal QA team gets early access to v2 via HTTP header routing
#   - Only 10% of public traffic is gradually shifted to v2 (canary)
#   - Chaos mode can be tested — but only ~5 out of 50 viewers see failures
#   - Phase 4 placeholders: health score and rollback engine shown
#
# This is what responsible DevOps teams do before every major release.
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\smart-rollout.ps1
# =============================================================================

# ── Formatting helpers ────────────────────────────────────────────────────────
function Print-Header($text) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "  $text" -ForegroundColor Green
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

function Print-Warning($text) {
    Write-Host "  !! $text" -ForegroundColor Yellow
}

function Print-Success($text) {
    Write-Host "  OK $text" -ForegroundColor Green
}

function Print-Placeholder($text) {
    Write-Host "  [PHASE 4] $text" -ForegroundColor DarkGray
}

# =============================================================================
# STEP 0 — Title & Explanation
# =============================================================================
Print-Header "STREAMSHIELD SMART ROLLOUT MODE"

Write-Host "  This mode simulates a SAFE rollout using internal QA and" -ForegroundColor White
Write-Host "  canary traffic — the DevOps way to release without downtime." -ForegroundColor White
Write-Host ""
Write-Host "  Rollout stages in this demo:" -ForegroundColor DarkGray
Write-Host "    Stage 1: v1 stays primary — all normal traffic goes to Blue" -ForegroundColor DarkGray
Write-Host "    Stage 2: QA team tests v2 using X-Internal-Team: true header" -ForegroundColor DarkGray
Write-Host "    Stage 3: 10% public traffic shifted to v2 (canary rollout)" -ForegroundColor DarkGray
Write-Host "    Stage 4: Health score + auto-rollback (Phase 4 — coming soon)" -ForegroundColor DarkGray
Write-Host ""

# =============================================================================
# STEP 1 — Enable Minikube NGINX Ingress Addon
# =============================================================================
Print-Step 1 "Enabling Minikube NGINX Ingress addon..."
Print-Info "This installs the NGINX ingress controller into your cluster."

minikube addons enable ingress

if ($LASTEXITCODE -ne 0) {
    Print-Warning "Failed to enable ingress. Is Minikube running?"
    Print-Warning "Run: minikube start --driver=docker"
    exit 1
}
Print-Success "Ingress addon enabled."
Write-Host ""

# =============================================================================
# STEP 2 — Wait for Ingress Controller to be Ready
# =============================================================================
Print-Step 2 "Waiting for NGINX ingress controller to be ready..."

$timeout = 90
$elapsed = 0
do {
    $podStatus = kubectl get pods -n ingress-nginx --no-headers 2>$null |
                 Select-String "ingress-nginx-controller"
    if ($podStatus -match "Running") {
        Print-Success "NGINX ingress controller is running."
        break
    }
    Write-Host "  .. Waiting ($elapsed/$timeout s)" -ForegroundColor DarkGray
    Start-Sleep 5
    $elapsed += 5
} while ($elapsed -lt $timeout)

Write-Host ""

# =============================================================================
# STEP 3 — Clean Up Any Existing Ingress Rules
# =============================================================================
Print-Step 3 "Cleaning up any previous rollout ingresses..."

kubectl delete -f k8s/unsafe-rollout.yaml         --ignore-not-found=true 2>$null
kubectl delete -f k8s/ingress-main.yaml           --ignore-not-found=true 2>$null
kubectl delete -f k8s/ingress-canary-10.yaml      --ignore-not-found=true 2>$null
kubectl delete -f k8s/ingress-internal-team.yaml  --ignore-not-found=true 2>$null

Start-Sleep 3
Print-Success "Previous ingresses removed."
Write-Host ""

# =============================================================================
# STEP 4 — Apply Main Production Ingress (v1 as Primary)
# =============================================================================
Print-Step 4 "Applying main production ingress (v1 Blue as primary)..."
Print-Info "Normal users → streamshield.local → v1 (stable, unchanged)"

kubectl apply -f k8s/ingress-main.yaml

if ($LASTEXITCODE -ne 0) {
    Print-Warning "Failed to apply main ingress. Aborting."
    exit 1
}
Print-Success "Main ingress applied. v1 is now the primary production route."
Write-Host ""

# =============================================================================
# STEP 5 — Apply Internal Team Ingress (QA Header Routing)
# =============================================================================
Print-Step 5 "Applying internal QA team ingress (header-based routing)..."
Print-Info "QA team can access v2 by sending: X-Internal-Team: true header"
Print-Info "Regular users without this header stay on v1 — completely unaffected."

kubectl apply -f k8s/ingress-internal-team.yaml

if ($LASTEXITCODE -ne 0) {
    Print-Warning "Failed to apply internal team ingress."
} else {
    Print-Success "Internal team ingress applied. QA can now reach v2 privately."
}
Write-Host ""

# =============================================================================
# STEP 6 — Apply 10% Canary Ingress (Public Traffic Split)
# =============================================================================
Print-Step 6 "Applying 10% canary ingress (public traffic split to v2)..."
Print-Info "~10% of all public traffic will now be routed to v2 (Green)."
Print-Info "~90% of users continue receiving v1 (Blue) as normal."

kubectl apply -f k8s/ingress-canary-10.yaml

if ($LASTEXITCODE -ne 0) {
    Print-Warning "Failed to apply canary ingress."
} else {
    Print-Success "Canary ingress applied. 10% of traffic now goes to v2."
}
Write-Host ""

# =============================================================================
# STEP 7 — Show Minikube IP and Hosts File Instruction
# =============================================================================
Print-Step 7 "Getting Minikube IP address..."

$MINIKUBE_IP = minikube ip
Write-Host ""
Write-Host "  Your Minikube IP is: " -NoNewline -ForegroundColor White
Write-Host $MINIKUBE_IP -ForegroundColor Cyan
Write-Host ""

Write-Host "  IMPORTANT — Windows Hosts File Setup" -ForegroundColor Yellow
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  If you haven't already, add this line to your hosts file:" -ForegroundColor White
Write-Host ""
Write-Host "    $MINIKUBE_IP streamshield.local" -ForegroundColor Green
Write-Host ""
Write-Host "  How to edit the hosts file:" -ForegroundColor White
Write-Host "    1. Open Notepad as Administrator" -ForegroundColor DarkGray
Write-Host "    2. Open: C:\Windows\System32\drivers\etc\hosts" -ForegroundColor DarkGray
Write-Host "    3. Add the line above and save" -ForegroundColor DarkGray
Write-Host ""

# =============================================================================
# STEP 8 — Verify All Ingress Rules
# =============================================================================
Print-Step 8 "Current ingress configuration in the cluster:"
Write-Host ""
kubectl get ingress -n streamshield
Write-Host ""

# =============================================================================
# STEP 9 — Test Normal User (should hit v1)
# =============================================================================
Print-Step 9 "Testing normal user request (should reach v1 Blue)..."
Print-Info "Sending: GET http://streamshield.local"
Write-Host ""

Start-Sleep 3   # Brief pause for ingress to propagate

try {
    $normalRes = Invoke-WebRequest -Uri "http://streamshield.local" `
                     -TimeoutSec 15 -ErrorAction Stop
    if ($normalRes.Content -match "v1|Stable|Blue") {
        Print-Success "Normal user correctly reached v1 (Blue). Status: $($normalRes.StatusCode)"
    } elseif ($normalRes.StatusCode -eq 200) {
        Print-Success "Normal user received HTTP 200. Status: $($normalRes.StatusCode)"
    } else {
        Print-Warning "Unexpected response. Status: $($normalRes.StatusCode)"
    }
} catch {
    Print-Warning "Could not reach http://streamshield.local"
    Print-Info "Ensure hosts file has: $MINIKUBE_IP streamshield.local"
    Print-Info "You can test manually: curl http://streamshield.local"
}
Write-Host ""

# =============================================================================
# STEP 10 — Test Internal QA User (should hit v2)
# =============================================================================
Print-Step 10 "Testing internal QA user (should reach v2 Green via header)..."
Print-Info "Sending: GET http://streamshield.local with header X-Internal-Team: true"
Write-Host ""

try {
    $headers = @{ "X-Internal-Team" = "true" }
    $qaRes = Invoke-WebRequest -Uri "http://streamshield.local" `
                 -Headers $headers -TimeoutSec 15 -ErrorAction Stop
    if ($qaRes.Content -match "v2|Smart|Green|Simulator") {
        Print-Success "QA user correctly reached v2 (Green). Status: $($qaRes.StatusCode)"
    } elseif ($qaRes.StatusCode -eq 200) {
        Print-Success "QA user received HTTP 200. Status: $($qaRes.StatusCode)"
    } else {
        Print-Warning "Unexpected response for QA user. Status: $($qaRes.StatusCode)"
    }
} catch {
    Print-Warning "Could not reach v2 via header routing."
    Print-Info "Manual test: curl -H 'X-Internal-Team: true' http://streamshield.local"
}
Write-Host ""

# =============================================================================
# STEP 11 — Enable Chaos Mode on v2 (via QA header)
# =============================================================================
Print-Step 11 "Enabling chaos mode on v2 via QA header..."
Print-Info "Only QA-routed traffic will reach v2 directly for this."
Print-Info "Public canary users (~10%) may also see failures in the load test."
Write-Host ""

$chaosEnabled = $false
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        $headers = @{ "X-Internal-Team" = "true" }
        $chaosRes = Invoke-WebRequest `
                        -Uri "http://streamshield.local/chaos/on" `
                        -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        $chaosEnabled = $true
        Print-Success "Chaos mode ENABLED on v2 via QA header."
        break
    } catch {
        Write-Host "  .. Attempt $attempt/3 — retrying..." -ForegroundColor DarkGray
        Start-Sleep 3
    }
}

if (-not $chaosEnabled) {
    Print-Warning "Could not enable chaos mode via header."
    Print-Info "Manual: curl -H 'X-Internal-Team: true' http://streamshield.local/chaos/on"
}
Write-Host ""

# =============================================================================
# STEP 12 — Phase 4 Placeholders
# =============================================================================
Print-Step 12 "Phase 4 systems status (coming in next phase)..."
Write-Host ""
Print-Placeholder "Health Score Monitor  : NOT ACTIVE (Phase 4)"
Print-Placeholder "Error Rate Tracker    : NOT ACTIVE (Phase 4)"
Print-Placeholder "Latency Analyzer      : NOT ACTIVE (Phase 4)"
Print-Placeholder "Rollback Engine       : NOT ACTIVE (Phase 4)"
Print-Placeholder "Alert Threshold       : NOT CONFIGURED (Phase 4)"
Write-Host ""
Write-Host "  In Phase 4, the health score engine will:" -ForegroundColor DarkGray
Write-Host "    - Monitor /metrics endpoint on both v1 and v2" -ForegroundColor DarkGray
Write-Host "    - Calculate health score from error rate + latency" -ForegroundColor DarkGray
Write-Host "    - Automatically rollback if health score drops below threshold" -ForegroundColor DarkGray
Write-Host ""

# =============================================================================
# STEP 13 — Run Load Test
# =============================================================================
Print-Step 13 "Running load test (50 virtual streaming viewers for 30 seconds)..."
Write-Host ""
Print-Info "In Smart Rollout: ~10% of virtual users hit v2 (canary)"
Print-Info "Expected: ~45 users see normal v1, ~5 users may see v2 failures"
Write-Host ""

$k6Available = Get-Command k6 -ErrorAction SilentlyContinue

if ($k6Available) {
    Print-Info "k6 found. Running load test..."
    Write-Host ""
    k6 run load-tests/viewer-load.js
} else {
    Print-Warning "k6 is not installed. Running fallback curl loop."
    Print-Info "Install k6: winget install k6  OR  choco install k6"
    Write-Host ""

    $errors    = 0
    $successes = 0

    Write-Host "  Simulating 50 viewers hitting /watch..." -ForegroundColor Yellow
    Write-Host ""

    for ($i = 1; $i -le 50; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "http://streamshield.local/watch" `
                     -TimeoutSec 8 -ErrorAction Stop
            if ($r.StatusCode -eq 200) {
                $successes++
                Write-Host "  [$i/50] OK  200" -ForegroundColor Green
            } else {
                $errors++
                Write-Host "  [$i/50] ERR $($r.StatusCode)" -ForegroundColor Red
            }
        } catch {
            $errors++
            Write-Host "  [$i/50] FAIL — $($_.Exception.Message)" -ForegroundColor Red
        }
        Start-Sleep 0.2
    }

    Write-Host ""
    Write-Host "  Fallback test complete: $successes OK, $errors FAILED" -ForegroundColor White
    Write-Host "  (Only canary users ~10% should have failures)" -ForegroundColor DarkGray
}

# =============================================================================
# STEP 14 — Print Smart Rollout Summary
# =============================================================================
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host "  SMART ROLLOUT — RESULT SUMMARY" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Rollout Strategy   : " -NoNewline; Write-Host "SMART (Canary + QA gated)" -ForegroundColor Green
Write-Host "  Stable Users       : " -NoNewline; Write-Host "~90% remain on v1 (Blue) — safe" -ForegroundColor Green
Write-Host "  Canary Users       : " -NoNewline; Write-Host "~10% routed to v2 (Green)" -ForegroundColor Yellow
Write-Host "  Internal QA        : " -NoNewline; Write-Host "Enabled via X-Internal-Team header" -ForegroundColor Green
Write-Host "  Chaos Mode         : " -NoNewline; Write-Host "ON on v2 (only canary users affected)" -ForegroundColor Yellow
Write-Host "  Health Score       : " -NoNewline; Write-Host "[Phase 4 — Prepared, not yet active]" -ForegroundColor DarkGray
Write-Host "  Rollback Engine    : " -NoNewline; Write-Host "[Phase 4 — Prepared, not yet active]" -ForegroundColor DarkGray
Write-Host "  Viewer Impact      : " -NoNewline; Write-Host "LIMITED — Only canary segment affected" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Compare to Unsafe Rollout:" -ForegroundColor Yellow
Write-Host "    Unsafe: 100% users see failures" -ForegroundColor Red
Write-Host "    Smart:  ~10% users see failures (canary), 90% stay safe" -ForegroundColor Green
Write-Host ""

# =============================================================================
# STEP 15 — Show Reset and Next Steps
# =============================================================================
Write-Host "  To reset the environment:" -ForegroundColor Yellow
Write-Host "    .\scripts\reset-rollout.ps1" -ForegroundColor Green
Write-Host ""
Write-Host "  To compare with unsafe mode:" -ForegroundColor Yellow
Write-Host "    .\scripts\reset-rollout.ps1" -ForegroundColor Green
Write-Host "    .\scripts\unsafe-rollout.ps1" -ForegroundColor Green
Write-Host ""
