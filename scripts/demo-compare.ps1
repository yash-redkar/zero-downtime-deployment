# =============================================================================
# StreamShield — Full Demo Comparison Script
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Guides the presenter through the complete StreamShield demo:
#   1. Show current system state
#   2. Run Unsafe Rollout (bad release)
#   3. Check health score → shows failures
#   4. Reset the environment
#   5. Run Smart Rollout (safe release)
#   6. Run auto rollback → shows protection
#   7. Print the final comparison table
#
# This is the PRESENTATION SCRIPT — run this during your capstone demo.
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\demo-compare.ps1
# =============================================================================

# ── Formatting helpers ────────────────────────────────────────────────────────
function Print-Banner($text, $color = "Cyan") {
    Write-Host ""
    Write-Host ("█" * 62) -ForegroundColor $color
    Write-Host "  $text" -ForegroundColor White
    Write-Host ("█" * 62) -ForegroundColor $color
    Write-Host ""
}

function Print-Phase($n, $title, $color = "Yellow") {
    Write-Host ""
    Write-Host ("─" * 62) -ForegroundColor DarkGray
    Write-Host "  DEMO PHASE $n — $title" -ForegroundColor $color
    Write-Host ("─" * 62) -ForegroundColor DarkGray
    Write-Host ""
}

function Print-Instruction($text) {
    Write-Host "  ▶ $text" -ForegroundColor Cyan
}

function Print-Info($text) {
    Write-Host "  $text" -ForegroundColor DarkGray
}

function Pause-Demo($msg = "Press ENTER to continue to the next phase...") {
    Write-Host ""
    Write-Host "  >> $msg" -ForegroundColor Yellow
    Read-Host
}

# =============================================================================
Print-Banner "STREAMSHIELD FINAL DEMO — Zero-Downtime Release Simulator" "Magenta"

Write-Host "  Project: StreamShield Simulator" -ForegroundColor White
Write-Host "  Demo:    Unsafe Rollout vs Smart Rollout" -ForegroundColor White
Write-Host "  Phases:  Phase 1 → 2 → 3 → 4 (complete capstone)" -ForegroundColor White
Write-Host ""
Write-Host "  This script will guide you through the full demo." -ForegroundColor DarkGray
Write-Host "  Each phase pauses and waits for you to press ENTER." -ForegroundColor DarkGray
Write-Host ""

Pause-Demo "Press ENTER to begin the demo..."

# =============================================================================
# DEMO PHASE 1 — Show Current System State
# =============================================================================
Print-Phase 1 "CURRENT SYSTEM STATE" "Cyan"

Write-Host "  Showing all Kubernetes resources in the streamshield namespace." -ForegroundColor White
Write-Host ""

Print-Instruction "kubectl get all -n streamshield"
Write-Host ""
kubectl get all -n streamshield
Write-Host ""

Print-Instruction "kubectl get ingress -n streamshield"
Write-Host ""
kubectl get ingress -n streamshield

Write-Host ""
Write-Host "  TALKING POINT:" -ForegroundColor Yellow
Write-Host "  v1 (Blue) and v2 (Green) are both running in Kubernetes." -ForegroundColor White
Write-Host "  They are isolated deployments with separate services." -ForegroundColor White
Write-Host "  Ingress controls who sees which version." -ForegroundColor White

Pause-Demo "Phase 1 done. Press ENTER to start Unsafe Rollout demo..."

# =============================================================================
# DEMO PHASE 2 — Unsafe Rollout Mode
# =============================================================================
Print-Phase 2 "UNSAFE ROLLOUT — The Wrong Way to Release" "Red"

Write-Host "  SCENARIO: A developer pushes v2 directly to 100% of users." -ForegroundColor White
Write-Host "  No QA. No canary. No rollback plan. Chaos mode will be ON." -ForegroundColor White
Write-Host ""
Write-Host "  TALKING POINT:" -ForegroundColor Yellow
Write-Host "  This is what happens when a team skips DevOps best practices." -ForegroundColor White
Write-Host "  All 50 virtual viewers will be routed to the buggy v2." -ForegroundColor White
Write-Host ""

Print-Instruction "Running: .\scripts\unsafe-rollout.ps1"
Write-Host ""

# Run the unsafe rollout script
try {
    & .\scripts\unsafe-rollout.ps1
} catch {
    Write-Host "  Could not auto-run unsafe-rollout.ps1" -ForegroundColor Yellow
    Write-Host "  Please run it manually: .\scripts\unsafe-rollout.ps1" -ForegroundColor Cyan
}

Pause-Demo "Unsafe rollout complete. Press ENTER to check health score..."

# =============================================================================
# DEMO PHASE 3 — Health Score Check (after Unsafe Rollout)
# =============================================================================
Print-Phase 3 "HEALTH SCORE CHECK — Measuring the Damage" "Red"

Write-Host "  The health score engine probes the platform and" -ForegroundColor White
Write-Host "  calculates a score based on real HTTP test results." -ForegroundColor White
Write-Host ""
Write-Host "  EXPECTED RESULT: Low health score — rollback required." -ForegroundColor Red
Write-Host ""

Print-Instruction "Running: .\scripts\health-score.ps1"
Write-Host ""

try {
    & .\scripts\health-score.ps1
} catch {
    Write-Host "  Could not auto-run health-score.ps1" -ForegroundColor Yellow
    Write-Host "  Please run it manually: .\scripts\health-score.ps1" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "  TALKING POINT:" -ForegroundColor Yellow
Write-Host "  Error rate > 5% → -30 points" -ForegroundColor Red
Write-Host "  High latency     → -20 points" -ForegroundColor Red
Write-Host "  Health score < 70 = ROLLBACK REQUIRED" -ForegroundColor Red

Pause-Demo "Health score checked. Press ENTER to reset the environment..."

# =============================================================================
# DEMO PHASE 4 — Reset Environment
# =============================================================================
Print-Phase 4 "RESET — Cleaning Up the Unsafe Rollout" "Yellow"

Write-Host "  Resetting to clean state before Smart Rollout demo." -ForegroundColor White
Write-Host ""

Print-Instruction "Running: .\scripts\reset-rollout.ps1"
Write-Host ""

try {
    & .\scripts\reset-rollout.ps1
} catch {
    Write-Host "  Could not auto-run reset-rollout.ps1" -ForegroundColor Yellow
    Write-Host "  Please run manually: .\scripts\reset-rollout.ps1" -ForegroundColor Cyan
}

Pause-Demo "Reset complete. Press ENTER to start Smart Rollout demo..."

# =============================================================================
# DEMO PHASE 5 — Smart Rollout Mode
# =============================================================================
Print-Phase 5 "SMART ROLLOUT — The Right Way to Release" "Green"

Write-Host "  SCENARIO: The team uses DevOps best practices." -ForegroundColor White
Write-Host "  v1 stays primary. QA tests v2 internally first." -ForegroundColor White
Write-Host "  Only 10% canary traffic goes to v2." -ForegroundColor White
Write-Host ""
Write-Host "  TALKING POINT:" -ForegroundColor Yellow
Write-Host "  90% of users stay safely on v1." -ForegroundColor Green
Write-Host "  Even with chaos ON, only the canary 10% is affected." -ForegroundColor Yellow
Write-Host ""

Print-Instruction "Running: .\scripts\smart-rollout.ps1"
Write-Host ""

try {
    & .\scripts\smart-rollout.ps1
} catch {
    Write-Host "  Could not auto-run smart-rollout.ps1" -ForegroundColor Yellow
    Write-Host "  Please run manually: .\scripts\smart-rollout.ps1" -ForegroundColor Cyan
}

Pause-Demo "Smart rollout complete. Press ENTER to run auto rollback..."

# =============================================================================
# DEMO PHASE 6 — Auto Rollback
# =============================================================================
Print-Phase 6 "AUTO ROLLBACK — The Safety Net" "Cyan"

Write-Host "  The auto rollback engine detects bad metrics and" -ForegroundColor White
Write-Host "  restores v1 automatically — no human needed." -ForegroundColor White
Write-Host ""
Write-Host "  TALKING POINT:" -ForegroundColor Yellow
Write-Host "  In Smart Rollout, auto rollback is the final guard." -ForegroundColor White
Write-Host "  If the 10% canary shows problems, the system rolls back." -ForegroundColor White
Write-Host "  90% of users were never affected." -ForegroundColor Green
Write-Host ""

Print-Instruction "Running: .\scripts\auto-rollback.ps1"
Write-Host ""

try {
    & .\scripts\auto-rollback.ps1
} catch {
    Write-Host "  Could not auto-run auto-rollback.ps1" -ForegroundColor Yellow
    Write-Host "  Please run manually: .\scripts\auto-rollback.ps1" -ForegroundColor Cyan
}

Pause-Demo "Auto rollback complete. Press ENTER for the final comparison..."

# =============================================================================
# DEMO PHASE 7 — Final Comparison Table
# =============================================================================
Print-Phase 7 "FINAL COMPARISON — Unsafe vs Smart Rollout" "Magenta"

Write-Host ""
Write-Host ("  {0,-30} {1,-16} {2}" -f "Metric", "Unsafe Rollout", "Smart Rollout") -ForegroundColor White
Write-Host ("  " + "─" * 60) -ForegroundColor DarkGray
Write-Host ("  {0,-30} " -f "Traffic to v2") -NoNewline
Write-Host ("{0,-16} " -f "100% (all users)") -NoNewline -ForegroundColor Red
Write-Host "10% (canary only)" -ForegroundColor Green

Write-Host ("  {0,-30} " -f "Internal QA") -NoNewline
Write-Host ("{0,-16} " -f "Skipped x") -NoNewline -ForegroundColor Red
Write-Host "Enabled ✓" -ForegroundColor Green

Write-Host ("  {0,-30} " -f "Canary Rollout") -NoNewline
Write-Host ("{0,-16} " -f "Disabled x") -NoNewline -ForegroundColor Red
Write-Host "10% — Active ✓" -ForegroundColor Green

Write-Host ("  {0,-30} " -f "Health Score") -NoNewline
Write-Host ("{0,-16} " -f "Not Used x") -NoNewline -ForegroundColor Red
Write-Host "Active — 0-100 scale ✓" -ForegroundColor Green

Write-Host ("  {0,-30} " -f "Auto Rollback") -NoNewline
Write-Host ("{0,-16} " -f "Not Available x") -NoNewline -ForegroundColor Red
Write-Host "Triggers at score < 70 ✓" -ForegroundColor Green

Write-Host ("  {0,-30} " -f "Viewer Impact") -NoNewline
Write-Host ("{0,-16} " -f "HIGH — all users") -NoNewline -ForegroundColor Red
Write-Host "LOW — canary only (~10%)" -ForegroundColor Green

Write-Host ("  {0,-30} " -f "Rollback Time") -NoNewline
Write-Host ("{0,-16} " -f "Manual — minutes") -NoNewline -ForegroundColor Red
Write-Host "Automatic — seconds ✓" -ForegroundColor Green

Write-Host ""

# =============================================================================
# Final Banner
# =============================================================================
Print-Banner "DEMO COMPLETE — StreamShield Simulator" "Green"

Write-Host "  Project Summary:" -ForegroundColor White
Write-Host "    Phase 1 : Flask v1 + v2 Apps · Docker · Chaos Mode" -ForegroundColor DarkGray
Write-Host "    Phase 2 : Kubernetes Blue-Green Deployment · Minikube" -ForegroundColor DarkGray
Write-Host "    Phase 3 : NGINX Ingress · Canary Traffic · k6 Load Test" -ForegroundColor DarkGray
Write-Host "    Phase 4 : Health Score Engine · Auto Rollback · CI · Docs" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Thank you!" -ForegroundColor Cyan
Write-Host ""
