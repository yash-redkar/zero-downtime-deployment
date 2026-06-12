// =============================================================================
// StreamShield Simulator — k6 Load Test Script
// =============================================================================
//
// This script simulates streaming viewers hitting the StreamShield platform.
// It is used to demonstrate the difference between:
//
//   Unsafe Rollout:  All 50 virtual users hit v2 → many failures visible
//   Smart Rollout:   50 virtual users hit the ingress → only ~10% hit v2
//                    So only ~5 users experience failures (if chaos is ON)
//
// WHAT IS k6?
// ──────────────
// k6 is an open-source load testing tool. It runs this JavaScript file
// and sends real HTTP requests from virtual users (VUs) simultaneously.
// No browser is opened — it just makes HTTP requests and measures results.
//
// HOW TO RUN:
// ───────────
// Default (uses http://streamshield.local):
//   k6 run load-tests/viewer-load.js
//
// Custom URL (e.g., direct Docker test):
//   k6 run -e BASE_URL=http://localhost:5002 load-tests/viewer-load.js
//
// HOW TO INSTALL k6 ON WINDOWS:
//   winget install k6                    (Windows Package Manager)
//   choco install k6                     (Chocolatey)
//   Or download from: https://k6.io/docs/get-started/installation/
//
// =============================================================================

import http from "k6/http";
import { check, sleep } from "k6";

// ── Test Configuration ────────────────────────────────────────────────────────
export const options = {
  // Simulate 50 virtual users (concurrent streaming viewers)
  // running for 30 seconds total
  vus: 50,
  duration: "30s",

  // Thresholds define what "pass" means for this test.
  // These will show RED in the output if the app is having failures.
  thresholds: {
    // Less than 15% of requests should fail (generous threshold for demo)
    http_req_failed: ["rate<0.15"],

    // 95% of requests should complete within 3 seconds
    http_req_duration: ["p(95)<3000"],
  },
};

// ── Base URL ──────────────────────────────────────────────────────────────────
// Uses the BASE_URL environment variable if provided, otherwise defaults
// to http://streamshield.local (requires hosts file entry on Windows)
const BASE_URL = __ENV.BASE_URL || "http://streamshield.local";

// ── Virtual User Behaviour ───────────────────────────────────────────────────
// This function runs once per virtual user per iteration.
// Each virtual user simulates one streaming viewer navigating the platform.
export default function () {
  // ── Step 1: Visit the Homepage ────────────────────────────────────────────
  // Simulates a viewer landing on the streaming platform
  const homeRes = http.get(`${BASE_URL}/`);

  check(homeRes, {
    "homepage status is 200": (r) => r.status === 200,
  });

  // Small pause — simulates the viewer browsing the homepage
  sleep(0.5);

  // ── Step 2: Browse the Movie List ─────────────────────────────────────────
  // Simulates a viewer looking at available movies before choosing one
  const moviesRes = http.get(`${BASE_URL}/movies`);

  check(moviesRes, {
    "movies status is 200": (r) => r.status === 200,
  });

  sleep(0.3);

  // ── Step 3: Start Watching (Most Critical Endpoint) ───────────────────────
  // This is where chaos mode failures show up.
  // In Unsafe Rollout + chaos ON:  many 500 errors here
  // In Smart Rollout + chaos ON:   only ~10% of virtual users hit v2
  //                                so only ~5 out of 50 VUs see failures
  const watchRes = http.get(`${BASE_URL}/watch`);

  check(watchRes, {
    // In unsafe mode with chaos ON, this check will FAIL frequently
    // k6 will report the failure rate in the output summary
    "watch status is 200": (r) => r.status === 200,

    // Check that the response has actual content (not empty)
    "watch has content": (r) => r.body && r.body.length > 100,
  });

  // Slightly longer pause — simulates the viewer watching content
  sleep(1);
}
