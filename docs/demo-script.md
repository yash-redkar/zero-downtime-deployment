# StreamShield Simulator — Demo Presentation Script
## 3–5 Minute Capstone Demo Flow

> **For the presenter:** This is your word-for-word guide for the demo.
> Text in **[brackets]** = actions to take. Everything else = what to say.

---

## Before You Start (Setup — 5 minutes before demo)

```powershell
# Run this before anyone is watching
cd D:\Devops\StreamShield
.\scripts\verify-system.ps1
.\scripts\reset-rollout.ps1
```

Make sure:
- Terminal is open at `D:\Devops\StreamShield`
- Browser is open at `http://streamshield.local` (showing v1)
- Font size in terminal is readable from a distance

---

## INTRODUCTION (~30 seconds)

> "Hello everyone. I'm presenting StreamShield Simulator — a DevOps capstone project
> that simulates zero-downtime releases for streaming platforms.
>
> The core question this project answers is:
> **What happens when a streaming company pushes a new release to production?**
>
> There are two ways to do it — the wrong way, and the right way.
> I'm going to show you both."

**[Open browser at http://streamshield.local — shows v1 homepage]**

> "This is v1 — the stable production version. It's running inside Kubernetes
> on a local Minikube cluster. Millions of users are streaming content through this."

---

## PART 1 — Show the Architecture (~30 seconds)

**[Run in terminal:]**
```powershell
kubectl get all -n streamshield
```

> "You can see two deployments — Blue and Green — each running 2 pods.
> Blue is v1, the current stable release. Green is v2, the new release candidate.
>
> They are completely isolated — separate pods, separate services, separate health probes.
> Users only see what the Ingress controller sends them to."

---

## PART 2 — Unsafe Rollout Demo (~60 seconds)

> "Let me show you what happens with a **bad deployment strategy**.
> Imagine a developer just ran `kubectl apply` and pushed v2 to everyone at once."

**[Run in terminal:]**
```powershell
.\scripts\unsafe-rollout.ps1
```

> "What you're seeing now:
> - The ingress is reconfigured to send 100% of traffic to v2
> - Chaos mode is enabled — simulating a buggy release
> - 50 virtual streaming viewers are hitting the platform simultaneously"

**[Wait for load test to complete. Show the failure output]**

> "Look at the results. A large percentage of requests are failing with 500 errors.
> Viewers are getting buffering. Playback is broken.
>
> And the critical part? **There is no rollback available.**
> Every single user — all 50 virtual viewers — is stuck on this broken v2."

---

## PART 3 — Health Score (~45 seconds)

> "Now let's quantify how bad this is using our health score engine."

**[Run in terminal:]**
```powershell
.\scripts\health-score.ps1
```

> "The health score engine probes the platform 20 times and calculates a score out of 100.
>
> **[Point at the score in the terminal]**
>
> A score below 70 means rollback is required. You can see the penalties:
> - High error rate → minus 30 points
> - High latency → minus 20 points
> - Playback failures → minus 25 points
>
> This is a multi-signal health check — the same kind used by Netflix, Google,
> and Amazon SRE teams to make deployment decisions automatically."

---

## PART 4 — Reset (~15 seconds)

**[Run in terminal:]**
```powershell
.\scripts\reset-rollout.ps1
```

> "I've reset the environment. Traffic is back to stable v1. Let me now show
> how a **responsible DevOps team** would have handled this release."

---

## PART 5 — Smart Rollout Demo (~60 seconds)

> "This is Smart Rollout Mode — the DevOps best practice."

**[Run in terminal:]**
```powershell
.\scripts\smart-rollout.ps1
```

> "Here's what's different:
>
> **Stage 1** — The main ingress still points to v1. All normal users stay on v1.
>
> **Stage 2** — Our internal QA team can access v2 using a special header.
>   `curl -H 'X-Internal-Team: true' http://streamshield.local`
>   Only QA engineers see v2. Zero real users are affected.
>
> **Stage 3** — We shift just 10% of public traffic to v2 using NGINX canary routing.
>   90% of users are still safely on v1.
>
> Even with chaos mode ON — if v2 breaks for the canary group,
> **90% of our users never notice anything.**"

---

## PART 6 — Auto Rollback (~45 seconds)

> "But we don't want a human watching dashboards at 3 AM.
> Let me show you the auto rollback engine."

**[Run in terminal:]**
```powershell
.\scripts\auto-rollback.ps1
```

> "The auto rollback engine:
> 1. Runs 20 HTTP probes against the live cluster
> 2. Calculates the health score in real time
> 3. If the score is below 70, it automatically:
>    - Removes all canary ingresses
>    - Restores the main ingress to v1
>    - Turns off chaos mode
>
> **No human intervention. No manual kubectl commands. No 3 AM panic call.**
>
> In the Smart Rollout scenario, the system detected the bad release,
> confirmed it affected only the canary 10%, and rolled back in under 30 seconds."

---

## CONCLUSION (~30 seconds)

**[Show the final comparison]**

```powershell
# Optional — show if time allows
.\scripts\demo-compare.ps1
```

> "Let me summarize what this project demonstrates:
>
> | | Unsafe Rollout | Smart Rollout |
> |---|---|---|
> | Users affected | 100% | 10% (canary only) |
> | Rollback time | Minutes (manual) | Seconds (automatic) |
> | Detection | Users complain | Health score engine |
>
> **This is how companies like Netflix, Hotstar, and Google release software**
> to millions of users every day without downtime.
>
> StreamShield Simulator implements the full DevOps release pipeline:
> - Phase 1: Flask apps with Prometheus metrics
> - Phase 2: Kubernetes blue-green deployment
> - Phase 3: NGINX canary traffic control with k6 load testing
> - Phase 4: Health score engine and automated rollback
>
> Thank you."

---

## Q&A Preparation

**Q: Why did you use Minikube instead of a cloud cluster?**
> "Minikube gives us a real Kubernetes cluster locally for free. The concepts are identical
> to GKE, EKS, or AKS — the only difference is scale. In a production environment,
> you'd run the same YAML manifests on a cloud cluster."

**Q: What is the health score based on?**
> "It combines 5 signals: error rate, playback failure rate, response latency, pod readiness,
> and restart count. Each has a different weight based on how much it impacts streaming users.
> Playback failures matter more than pod restarts for a streaming platform."

**Q: How is this different from just using Kubernetes readiness probes?**
> "Readiness probes check if a pod is ready to receive traffic. They can't tell you if
> 40% of your /watch requests are failing, or if latency has spiked to 1200ms for users.
> The health score engine measures end-to-end user experience, not just pod health."

**Q: Could this be extended to a real production system?**
> "Yes. Replace the PowerShell probes with Prometheus alerting rules.
> Replace the manual scripts with a Kubernetes operator or GitHub Actions workflow.
> The ingress canary annotations and health score formula work exactly the same way."
