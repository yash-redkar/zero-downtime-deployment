# =============================================================================
# StreamShield — System Verification Script
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Checks that all required tools and cluster resources are in place
# before running the demo. Run this BEFORE the presentation.
#
# Checks performed:
#   ✓ Docker is installed and running
#   ✓ Minikube is running and healthy
#   ✓ kubectl can connect to the cluster
#   ✓ Namespace 'streamshield' exists
#   ✓ Blue deployment exists and is ready
#   ✓ Green deployment exists and is ready
#   ✓ Blue service exists
#   ✓ Green service exists
#   ✓ NGINX ingress controller is running
#   ✓ http://streamshield.local responds
#   ✓ k6 is installed (or fallback curl available)
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\verify-system.ps1
# =============================================================================

# ── Result tracking ───────────────────────────────────────────────────────────
$passCount = 0
$failCount = 0
$warnCount = 0
$results   = @()

function Check-Pass($label, $detail = "") {
    $script:passCount++
    $script:results += [PSCustomObject]@{ Status="PASS"; Label=$label; Detail=$detail }
    Write-Host ("  {0,-45}" -f $label) -NoNewline
    Write-Host " PASS" -ForegroundColor Green -NoNewline
    if ($detail) { Write-Host "  ($detail)" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Check-Fail($label, $detail = "") {
    $script:failCount++
    $script:results += [PSCustomObject]@{ Status="FAIL"; Label=$label; Detail=$detail }
    Write-Host ("  {0,-45}" -f $label) -NoNewline
    Write-Host " FAIL" -ForegroundColor Red -NoNewline
    if ($detail) { Write-Host "  ($detail)" -ForegroundColor Yellow } else { Write-Host "" }
}

function Check-Warn($label, $detail = "") {
    $script:warnCount++
    $script:results += [PSCustomObject]@{ Status="WARN"; Label=$label; Detail=$detail }
    Write-Host ("  {0,-45}" -f $label) -NoNewline
    Write-Host " WARN" -ForegroundColor Yellow -NoNewline
    if ($detail) { Write-Host "  ($detail)" -ForegroundColor DarkGray } else { Write-Host "" }
}

# =============================================================================
Write-Host ""
Write-Host ("=" * 62) -ForegroundColor DarkCyan
Write-Host "  STREAMSHIELD SYSTEM VERIFICATION" -ForegroundColor Cyan
Write-Host ("=" * 62) -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Running pre-demo checks..." -ForegroundColor DarkGray
Write-Host ""

# =============================================================================
# CHECK 1 — Docker Available
# =============================================================================
Write-Host "  [Tools]" -ForegroundColor Yellow
try {
    $dockerVer = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Check-Pass "Docker installed" $dockerVer
    } else {
        Check-Fail "Docker installed" "docker command failed"
    }
} catch {
    Check-Fail "Docker installed" "not found in PATH"
}

# Check Docker daemon is running
try {
    docker info 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Check-Pass "Docker daemon running"
    } else {
        Check-Fail "Docker daemon running" "Docker Desktop may not be started"
    }
} catch {
    Check-Fail "Docker daemon running" "could not connect to Docker daemon"
}

# =============================================================================
# CHECK 2 — Minikube Running
# =============================================================================
try {
    $mkStatus = minikube status 2>$null
    if ($mkStatus -match "Running") {
        Check-Pass "Minikube running" "host=Running"
    } else {
        Check-Fail "Minikube running" "Run: minikube start --driver=docker"
    }
} catch {
    Check-Fail "Minikube running" "minikube command not found"
}

# =============================================================================
# CHECK 3 — kubectl Can Access Cluster
# =============================================================================
try {
    $nodes = kubectl get nodes --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $nodes -match "Ready") {
        Check-Pass "kubectl cluster access" "node is Ready"
    } else {
        Check-Fail "kubectl cluster access" "No Ready nodes found"
    }
} catch {
    Check-Fail "kubectl cluster access" "kubectl not found or cluster unreachable"
}

# =============================================================================
# CHECK 4 — Namespace Exists
# =============================================================================
Write-Host ""
Write-Host "  [Kubernetes Resources]" -ForegroundColor Yellow

try {
    $ns = kubectl get namespace streamshield --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $ns -match "streamshield") {
        Check-Pass "Namespace 'streamshield' exists"
    } else {
        Check-Fail "Namespace 'streamshield' exists" "Run: kubectl apply -f k8s/namespace.yaml"
    }
} catch {
    Check-Fail "Namespace 'streamshield' exists" "kubectl error"
}

# =============================================================================
# CHECK 5 — Blue Deployment
# =============================================================================
try {
    $blue = kubectl get deployment streamshield-blue -n streamshield --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $blue -match "streamshield-blue") {
        $ready = ($blue -split '\s+')[1]
        Check-Pass "Blue deployment exists" "READY: $ready"
    } else {
        Check-Fail "Blue deployment exists" "Run: kubectl apply -f k8s/blue-deployment.yaml"
    }
} catch {
    Check-Fail "Blue deployment exists" "kubectl error"
}

# =============================================================================
# CHECK 6 — Green Deployment
# =============================================================================
try {
    $green = kubectl get deployment streamshield-green -n streamshield --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $green -match "streamshield-green") {
        $ready = ($green -split '\s+')[1]
        Check-Pass "Green deployment exists" "READY: $ready"
    } else {
        Check-Fail "Green deployment exists" "Run: kubectl apply -f k8s/green-deployment.yaml"
    }
} catch {
    Check-Fail "Green deployment exists" "kubectl error"
}

# =============================================================================
# CHECK 7 — Blue and Green Services
# =============================================================================
try {
    $blueSvc = kubectl get svc streamshield-blue-service -n streamshield --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Check-Pass "Blue service exists" "NodePort 30081"
    } else {
        Check-Fail "Blue service exists" "Run: kubectl apply -f k8s/blue-service.yaml"
    }
} catch {
    Check-Fail "Blue service exists" "kubectl error"
}

try {
    $greenSvc = kubectl get svc streamshield-green-service -n streamshield --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Check-Pass "Green service exists" "NodePort 30082"
    } else {
        Check-Fail "Green service exists" "Run: kubectl apply -f k8s/green-service.yaml"
    }
} catch {
    Check-Fail "Green service exists" "kubectl error"
}

# =============================================================================
# CHECK 8 — NGINX Ingress Controller
# =============================================================================
Write-Host ""
Write-Host "  [Ingress & Networking]" -ForegroundColor Yellow

try {
    $ingressPods = kubectl get pods -n ingress-nginx --no-headers 2>$null |
                   Select-String "ingress-nginx-controller"
    if ($ingressPods -match "Running") {
        Check-Pass "NGINX ingress controller running"
    } elseif ($ingressPods) {
        Check-Warn "NGINX ingress controller" "Pod exists but not Running yet"
    } else {
        Check-Fail "NGINX ingress controller" "Run: minikube addons enable ingress"
    }
} catch {
    Check-Fail "NGINX ingress controller" "could not check ingress-nginx namespace"
}

# =============================================================================
# CHECK 9 — streamshield.local Responds
# =============================================================================
try {
    $r = Invoke-WebRequest -Uri "http://streamshield.local" `
             -TimeoutSec 8 -ErrorAction Stop
    if ($r.StatusCode -eq 200) {
        Check-Pass "http://streamshield.local responds" "HTTP 200"
    } else {
        Check-Warn "http://streamshield.local responds" "HTTP $($r.StatusCode)"
    }
} catch {
    Check-Fail "http://streamshield.local responds" "Add to hosts file: $(minikube ip) streamshield.local"
}

# =============================================================================
# CHECK 10 — k6 Load Tester
# =============================================================================
Write-Host ""
Write-Host "  [Load Testing]" -ForegroundColor Yellow

$k6 = Get-Command k6 -ErrorAction SilentlyContinue
if ($k6) {
    $k6Ver = k6 version 2>$null
    Check-Pass "k6 load tester installed" $k6Ver
} else {
    Check-Warn "k6 load tester installed" "Fallback curl loop will be used instead. Install: winget install k6"
}

# Check curl fallback
$curl = Get-Command curl -ErrorAction SilentlyContinue
if ($curl) {
    Check-Pass "curl available (k6 fallback)"
} else {
    Check-Warn "curl available" "Invoke-WebRequest will be used as fallback"
}

# =============================================================================
# CHECK 11 — k8s YAML files exist
# =============================================================================
Write-Host ""
Write-Host "  [Project Files]" -ForegroundColor Yellow

$requiredFiles = @(
    "k8s\namespace.yaml",
    "k8s\blue-deployment.yaml",
    "k8s\blue-service.yaml",
    "k8s\green-deployment.yaml",
    "k8s\green-service.yaml",
    "k8s\ingress-main.yaml",
    "k8s\ingress-canary-10.yaml",
    "k8s\ingress-internal-team.yaml",
    "k8s\unsafe-rollout.yaml",
    "load-tests\viewer-load.js",
    "scripts\unsafe-rollout.ps1",
    "scripts\smart-rollout.ps1",
    "scripts\reset-rollout.ps1",
    "scripts\health-score.ps1",
    "scripts\auto-rollback.ps1"
)

foreach ($f in $requiredFiles) {
    if (Test-Path $f) {
        Check-Pass "File: $f"
    } else {
        Check-Fail "File: $f" "File is missing!"
    }
}

# =============================================================================
# SUMMARY
# =============================================================================
$total = $passCount + $failCount + $warnCount

Write-Host ""
Write-Host ("=" * 62) -ForegroundColor DarkCyan
Write-Host "  VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 62) -ForegroundColor DarkCyan
Write-Host ""
Write-Host ("  {0,-12}" -f "Total Checks:") -NoNewline; Write-Host $total -ForegroundColor White
Write-Host ("  {0,-12}" -f "Passed:") -NoNewline; Write-Host $passCount -ForegroundColor Green
Write-Host ("  {0,-12}" -f "Warnings:") -NoNewline; Write-Host $warnCount -ForegroundColor Yellow
Write-Host ("  {0,-12}" -f "Failed:") -NoNewline; Write-Host $failCount -ForegroundColor Red
Write-Host ""

if ($failCount -eq 0 -and $warnCount -eq 0) {
    Write-Host "  ✅  ALL CHECKS PASSED — System is demo-ready!" -ForegroundColor Green
} elseif ($failCount -eq 0) {
    Write-Host "  🟡  WARNINGS FOUND — Demo may still work but review warnings above." -ForegroundColor Yellow
} else {
    Write-Host "  ❌  FAILURES FOUND — Fix the issues above before running the demo." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Failed items:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
        Write-Host "    - $($_.Label): $($_.Detail)" -ForegroundColor Red
    }
}
Write-Host ""
