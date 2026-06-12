# =============================================================================
# StreamShield — Final Demo Orchestrator
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
# ───────────────────────
# Provides a flawless, one-command execution for your capstone presentation.
# 
# 1. Runs the system verification script to ensure cluster health.
# 2. If healthy, launches the interactive demo-compare script.
#
# RUN FROM PROJECT ROOT:
#   cd D:\Devops\StreamShield
#   .\scripts\run-final-demo.ps1
# =============================================================================

function Print-Header($text) {
    Write-Host ""
    Write-Host ("=" * 62) -ForegroundColor Magenta
    Write-Host "  $text" -ForegroundColor White
    Write-Host ("=" * 62) -ForegroundColor Magenta
    Write-Host ""
}

Print-Header "STREAMSHIELD SIMULATOR — CAPSTONE PRESENTATION"

Write-Host "  Step 1: Running system verification..." -ForegroundColor Yellow
Write-Host ""

# Run verification
try {
    & .\scripts\verify-system.ps1
} catch {
    Write-Host "  [Error] Failed to execute verify-system.ps1" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  Review the verification summary above." -ForegroundColor White
Write-Host "  If there are FAILURES (Red), press Ctrl+C to cancel and fix them." -ForegroundColor Yellow
Write-Host "  If all is well, proceed with the demo." -ForegroundColor Green
Write-Host ""
Write-Host "  >> Press ENTER to start the interactive demo presentation..." -ForegroundColor Cyan
Read-Host

Write-Host "  Step 2: Launching final demo script..." -ForegroundColor Yellow
Write-Host ""

# Run the actual demo script
try {
    & .\scripts\demo-compare.ps1
} catch {
    Write-Host "  [Error] Failed to execute demo-compare.ps1" -ForegroundColor Red
    exit 1
}
