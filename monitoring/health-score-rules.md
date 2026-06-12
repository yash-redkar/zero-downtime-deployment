# =============================================================================
# StreamShield — Health Score Rules & Formula (Phase 4)
# =============================================================================
#
# This document defines the health score system used by:
#   scripts/health-score.ps1    — calculates and reports score
#   scripts/auto-rollback.ps1   — calculates and acts on score
#
# The health score is a single number (0–100) that represents the
# overall reliability of the currently deployed release.
# It combines multiple signals into one actionable decision.
# =============================================================================

## Why a Health Score?

In real streaming platforms, a deployment is "healthy" only when ALL of
the following are true simultaneously:
- Users can load content (low error rate)
- Content loads fast enough (low latency)
- Video plays without interruption (low playback failures)
- The infrastructure is stable (pods are ready, not restarting)

Looking at any single metric in isolation is misleading:
- Low error rate + high latency = buffering (users still leave)
- Low latency + high playback failures = broken player (silent failure)
- All metrics OK + pod restarting = upcoming crash risk

The health score combines all signals into one number the team can act on.

---

## Health Score Formula

```
Starting Score = 100

Penalties applied:

  IF error_rate > 5%             → subtract 30 points
  IF playback_failure_rate > 8%  → subtract 25 points
  IF avg_latency_ms > 800        → subtract 20 points
  IF any pod is NOT ready        → subtract 15 points
  IF restart_count > 0           → subtract 10 points

Final Score = max(0, Starting Score - sum of penalties)
```

### Score Decision Bands

| Score Range | Label | Action |
|---|---|---|
| 90 – 100 | ✅ Excellent | Continue rollout safely |
| 75 – 89 | 🟡 Healthy | Monitor closely |
| 60 – 74 | 🟠 Risky | Consider slowing canary |
| Below 60 | 🔴 Rollback Required | Trigger auto rollback |

---

## Threshold Values

| Metric | Safe Threshold | Penalty | Why This Value? |
|---|---|---|---|
| Error Rate | ≤ 5% | −30 pts | Industry standard SLO for web services |
| Playback Failure Rate | ≤ 8% | −25 pts | Streaming-specific: >8% causes viewer churn |
| Response Latency | ≤ 800ms | −20 pts | >800ms causes buffering on mobile connections |
| Pod Readiness | All ready | −15 pts | Not-ready pod = reduced capacity risk |
| Restart Count | 0 | −10 pts | Restarts indicate instability or crash loops |

---

## Rollback Trigger Conditions

A rollback is triggered if ANY of the following is true:

```
health_score < 70
OR
error_rate > 5%
OR
playback_failure_rate > 8%
OR
avg_latency_ms > 800
```

Note: The score threshold is 70 (not 60) because the individual metric
thresholds are conservative. If only one metric is bad, the score stays
above 60. The 70 threshold gives an early warning before the score reaches
the "Rollback Required" band.

---

## Why Error Rate Alone is Not Enough

Consider this scenario:

> v2 is deployed. Error rate is only 2% (below threshold).
> But average latency is 1,200ms and playback failure rate is 15%.

Using only error rate, the system would say "healthy" and not rollback.
But in reality:
- 15% of viewers see buffering or black screens (playback failure)
- Every page takes 1.2 seconds to load (terrible streaming UX)
- Viewers are abandoning the platform silently

The health score would calculate:
- Error rate: 2% → no penalty (below 5%)
- Playback failures: 15% → −25 points
- Latency: 1,200ms → −20 points
- Score: 100 − 25 − 20 = **55/100 → ROLLBACK REQUIRED**

This is the key advantage of multi-signal health scoring over single-metric alerting.

---

## Why Latency Matters for Streaming

Streaming platforms have strict latency requirements because:

1. **Buffering starts at ~500ms** for live sports on mobile networks
2. **Viewer abandonment** increases sharply after 800ms load time
3. **CDN cache misses** are often caused by slow origin server responses
4. **Live events** (cricket finals, premieres) have zero tolerance for delays

A backend latency of 1,000ms translates to:
- 3–5 seconds of buffering at the player level
- Higher rebuffering ratio (industry KPI)
- Lower viewer session length
- Lost subscription revenue

This is why `avg_latency_ms > 800` is a rollback trigger in StreamShield.

---

## Why Playback Failures Matter

Playback failures are different from HTTP 500 errors:
- A 500 error is immediately visible (red error page)
- A playback failure may look like "loading" for 10–30 seconds before failing
- Users often retry 2–3 times before giving up
- Playback failures are not always caught by standard uptime monitors

In StreamShield v2 with chaos mode ON:
- `/watch` sometimes returns HTTP 200 but with degraded content
- The player engine fails silently after a delay
- These failures increment `streamshield_playback_failures_total`
- Standard HTTP monitoring would miss these entirely

The health score explicitly tracks this metric because it matters most
for the streaming platform use case.

---

## Example Scenarios

### Scenario A — Unsafe Rollout with Chaos ON

```
error_rate          = 40%  → penalty: −30
playback_failure    = 40%  → penalty: −25
avg_latency_ms      = 1200 → penalty: −20
pods_ready          = yes  → no penalty
restart_count       = 0    → no penalty

Health Score = 100 − 30 − 25 − 20 = 25/100
Decision: ROLLBACK REQUIRED
```

### Scenario B — Smart Rollout (Canary 10%, Chaos ON)

```
error_rate          = 4%   → no penalty (below 5%)
playback_failure    = 7%   → no penalty (below 8%)
avg_latency_ms      = 600  → no penalty (below 800)
pods_ready          = yes  → no penalty
restart_count       = 0    → no penalty

Health Score = 100/100
Decision: EXCELLENT — Continue rollout
```

Only the canary 10% of users is affected. The overall platform health
remains high because 90% of traffic is still on stable v1.

### Scenario C — Mixed — Latency Spike Only

```
error_rate          = 2%   → no penalty
playback_failure    = 6%   → no penalty
avg_latency_ms      = 950  → penalty: −20
pods_ready          = yes  → no penalty
restart_count       = 1    → penalty: −10

Health Score = 100 − 20 − 10 = 70/100
Decision: RISKY — Monitor closely. Auto rollback at score < 70.
```
