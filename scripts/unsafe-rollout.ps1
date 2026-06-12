# =============================================================================
# StreamShield — Unsafe Rollout Mode Simulator
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Simulates the worst-case DevOps scenario:
#   - v2 is pushed DIRECTLY to 100% of production users
#   - No QA validation, no canary testing, no health monitoring
#   - Chaos mode is enabled to simulate a buggy v2 release
#   - Load test hits the platform with 50 virtual viewers
#   - Result: many users experience 500 errors and high latency
#
# This is what happens when a team releases without DevOps best practices.
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\unsafe-rollout.ps1
# =============================================================================

# ── Formatting helpers ────────────────────────────────────────────────────────
function Print-Header($text) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "  $text" -ForegroundColor Red
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
    Write-Host "  !! $text" -ForegroundColor Red
}

function Print-Success($text) {
    Write-Host "  OK $text" -ForegroundColor Green
}

# =============================================================================
# STEP 0 — Title & Explanation
# =============================================================================
Print-Header "STREAMSHIELD UNSAFE ROLLOUT MODE"

Write-Host "  This mode simulates a bad deployment where v2 is released" -ForegroundColor White
Write-Host "  to 100% of users without any safety checks." -ForegroundColor White
Write-Host ""
Write-Host "  What will happen:" -ForegroundColor DarkGray
Write-Host "    - Main ingress is replaced to point ALL traffic at v2 (Green)" -ForegroundColor DarkGray
Write-Host "    - Chaos mode is enabled to simulate a buggy v2 release" -ForegroundColor DarkGray
Write-Host "    - Load test sends 50 virtual viewers to the platform" -ForegroundColor DarkGray
Write-Host "    - Many viewers will experience 500 errors and high latency" -ForegroundColor DarkGray
Write-Host "    - No rollback will happen — users stay on broken v2" -ForegroundColor DarkGray
Write-Host ""

# =============================================================================
# STEP 1 — Enable Minikube NGINX Ingress Addon
# =============================================================================
Print-Step 1 "Enabling Minikube NGINX Ingress addon..."
Print-Info "This installs the NGINX ingress controller into your cluster."
Print-Info "First run may take 2-3 minutes. Subsequent runs are instant."

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
Print-Step 2 "Waiting for NGINX ingress controller pods to be ready..."
Print-Info "Checking ingress-nginx namespace for running pods..."

# Wait up to 90 seconds for ingress controller
$timeout = 90
$elapsed = 0
do {
    $podStatus = kubectl get pods -n ingress-nginx --no-headers 2>$null |
                 Select-String "ingress-nginx-controller"
    if ($podStatus -match "Running") {
        Print-Success "NGINX ingress controller is running."
        break
    }
    Write-Host "  .. Waiting for ingress controller ($elapsed/$timeout s)" -ForegroundColor DarkGray
    Start-Sleep 5
    $elapsed += 5
} while ($elapsed -lt $timeout)

if ($elapsed -ge $timeout) {
    Print-Warning "Ingress controller may still be starting. Continuing anyway..."
    Print-Info "Check status: kubectl get pods -n ingress-nginx"
}
Write-Host ""

# =============================================================================
# STEP 3 — Clean Up Any Existing Ingress Rules
# =============================================================================
Print-Step 3 "Cleaning up any existing ingress rules..."
Print-Info "Removing smart rollout ingresses to avoid conflicts."

kubectl delete -f k8s/ingress-main.yaml         --ignore-not-found=true 2>$null
kubectl delete -f k8s/ingress-canary-10.yaml    --ignore-not-found=true 2>$null
kubectl delete -f k8s/ingress-internal-team.yaml --ignore-not-found=true 2>$null
kubectl delete -f k8s/unsafe-rollout.yaml        --ignore-not-found=true 2>$null

Start-Sleep 3
Print-Success "Cleanup complete."
Write-Host ""

# =============================================================================
# STEP 4 — Apply Unsafe Rollout Ingress
# =============================================================================
Print-Step 4 "Applying UNSAFE rollout ingress..."
Print-Warning "This routes 100% of traffic directly to v2 (Green environment)."
Print-Info "No canary. No QA gate. No safety net."

kubectl apply -f k8s/unsafe-rollout.yaml

if ($LASTEXITCODE -ne 0) {
    Print-Warning "Failed to apply ingress. Check your Kubernetes connection."
    Print-Info "Run: kubectl get nodes"
    exit 1
}

Start-Sleep 3
Print-Success "Unsafe ingress applied. All traffic now goes to v2."
Write-Host ""

# =============================================================================
# STEP 5 — Show Minikube IP and Hosts File Instruction
# =============================================================================
Print-Step 5 "Getting Minikube IP address..."

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
# STEP 6 — Verify Ingress is Working
# =============================================================================
Print-Step 6 "Verifying ingress routes..."
Print-Info "Listing all ingress resources in the streamshield namespace:"
Write-Host ""

kubectl get ingress -n streamshield
Write-Host ""

# =============================================================================
# STEP 7 — Enable Chaos Mode on v2
# =============================================================================
Print-Step 7 "Enabling chaos mode on v2 (simulating buggy release)..."
Print-Warning "This makes /watch randomly return 500 errors and high latency."
Write-Host ""

Print-Info "Sending chaos/on request to http://streamshield.local/chaos/on"

# Try multiple times in case ingress is still warming up
$chaosEnabled = $false
for ($attempt = 1; $attempt -le 5; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri "http://streamshield.local/chaos/on" `
                        -TimeoutSec 10 -ErrorAction Stop
        $chaosEnabled = $true
        break
    } catch {
        Write-Host "  .. Attempt $attempt/5 — ingress warming up, retrying in 5s..." -ForegroundColor DarkGray
        Start-Sleep 5
    }
}

if ($chaosEnabled) {
    Print-Success "Chaos mode ENABLED. v2 is now simulating a broken release!"
} else {
    Print-Warning "Could not reach http://streamshield.local/chaos/on"
    Print-Info "Make sure your hosts file has: $MINIKUBE_IP streamshield.local"
    Print-Info "You can manually enable chaos: curl http://streamshield.local/chaos/on"
}
Write-Host ""

# =============================================================================
# STEP 8 — Run Load Test
# =============================================================================
Print-Step 8 "Running load test (50 virtual streaming viewers for 30 seconds)..."
Write-Host ""
Print-Warning "Expected result: HIGH failure rate — many viewers seeing 500 errors."
Write-Host ""

# Check if k6 is installed
$k6Available = Get-Command k6 -ErrorAction SilentlyContinue

if ($k6Available) {
    Print-Info "k6 found. Running load test..."
    Write-Host ""
    k6 run load-tests/viewer-load.js
} else {
    Print-Warning "k6 is not installed. Running fallback curl loop instead."
    Write-Host ""
    Print-Info "Install k6: winget install k6  OR  choco install k6"
    Print-Info "Docs: https://k6.io/docs/get-started/installation/"
    Write-Host ""
    Write-Host "  Running 50 curl requests to /watch (simulating viewers)..." -ForegroundColor Yellow
    Write-Host ""

    $errors   = 0
    $successes = 0

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
}

# =============================================================================
# STEP 9 — Print Result Summary
# =============================================================================
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host "  UNSAFE ROLLOUT — RESULT SUMMARY" -ForegroundColor Red
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Rollout Strategy  : " -NoNewline; Write-Host "UNSAFE (Direct 100% release)" -ForegroundColor Red
Write-Host "  Traffic to v2     : " -NoNewline; Write-Host "100% — All users hit v2 (Green)" -ForegroundColor Red
Write-Host "  Internal QA       : " -NoNewline; Write-Host "Skipped x" -ForegroundColor Red
Write-Host "  Canary            : " -NoNewline; Write-Host "Disabled x" -ForegroundColor Red
Write-Host "  Health Score      : " -NoNewline; Write-Host "Not Used x" -ForegroundColor Red
Write-Host "  Rollback          : " -NoNewline; Write-Host "Not Available x" -ForegroundColor Red
Write-Host "  Chaos Mode        : " -NoNewline; Write-Host "ON — v2 is broken" -ForegroundColor Red
Write-Host "  Viewer Impact     : " -NoNewline; Write-Host "HIGH — 500 errors for all users" -ForegroundColor Red
Write-Host ""
Write-Host "  DevOps Lesson:" -ForegroundColor Yellow
Write-Host "  This is why you NEVER push directly to 100% production." -ForegroundColor White
Write-Host "  Run scripts\smart-rollout.ps1 to see the safe alternative." -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# STEP 10 — Show How to Reset
# =============================================================================
Write-Host "  To reset the environment (undo this rollout):" -ForegroundColor Yellow
Write-Host "    .\scripts\reset-rollout.ps1" -ForegroundColor Green
Write-Host ""
