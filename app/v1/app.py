# =============================================================================
# StreamShield v1 — Stable Blue Production Version
# =============================================================================
# This represents the CURRENT PRODUCTION streaming platform.
# It is stable, healthy, and serving 100% of real users.
# In the DevOps simulator concept, this is the "Blue" environment.
# =============================================================================

import time
import random
from flask import Flask, jsonify, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# ─── Flask App Setup ─────────────────────────────────────────────────────────
app = Flask(__name__)

# ─── Prometheus Metrics ───────────────────────────────────────────────────────
# Counter: tracks total HTTP requests with labels for version, endpoint, status
http_requests_total = Counter(
    'streamshield_http_requests_total',
    'Total HTTP requests to StreamShield',
    ['version', 'endpoint', 'status']
)

# Histogram: tracks request latency in seconds
request_latency = Histogram(
    'streamshield_request_latency_seconds',
    'HTTP request latency in seconds',
    ['version', 'endpoint']
)

# Counter: tracks total playback failures
playback_failures_total = Counter(
    'streamshield_playback_failures_total',
    'Total playback failures',
    ['version']
)

# ─── Movie Data ───────────────────────────────────────────────────────────────
MOVIES = [
    {"id": 1, "title": "Cyber Heist",         "genre": "Thriller",       "rating": 8.4, "year": 2024, "duration": "2h 15m", "emoji": "🔐"},
    {"id": 2, "title": "Mumbai Nights",        "genre": "Drama",          "rating": 8.1, "year": 2024, "duration": "2h 05m", "emoji": "🌆"},
    {"id": 3, "title": "Live Sports Final",    "genre": "Sports",         "rating": 9.2, "year": 2024, "duration": "3h 00m", "emoji": "🏆"},
    {"id": 4, "title": "DevOps Documentary",   "genre": "Documentary",    "rating": 8.7, "year": 2024, "duration": "1h 45m", "emoji": "🚀"},
    {"id": 5, "title": "Space Wars",           "genre": "Sci-Fi",         "rating": 8.9, "year": 2024, "duration": "2h 30m", "emoji": "🌌"},
    {"id": 6, "title": "Code Breakers",        "genre": "Tech-Thriller",  "rating": 8.3, "year": 2024, "duration": "1h 55m", "emoji": "💻"},
]

# ─── Shared CSS & Fonts ───────────────────────────────────────────────────────
SHARED_CSS = """
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap');

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
        --navy:   #050818;
        --dark:   #0a0f1e;
        --card:   #0d1528;
        --border: #1a2744;
        --blue:   #3b82f6;
        --cyan:   #06b6d4;
        --purple: #8b5cf6;
        --green:  #10b981;
        --red:    #ef4444;
        --gold:   #f59e0b;
        --text:   #e2e8f0;
        --muted:  #64748b;
        --glass:  rgba(13, 21, 40, 0.85);
    }

    html { scroll-behavior: smooth; }

    body {
        font-family: 'Inter', system-ui, sans-serif;
        background: var(--navy);
        color: var(--text);
        min-height: 100vh;
        overflow-x: hidden;
    }

    /* Animated gradient background */
    body::before {
        content: '';
        position: fixed;
        inset: 0;
        background:
            radial-gradient(ellipse 80% 50% at 20% 10%, rgba(59,130,246,0.08) 0%, transparent 60%),
            radial-gradient(ellipse 60% 40% at 80% 80%, rgba(139,92,246,0.08) 0%, transparent 60%),
            radial-gradient(ellipse 50% 60% at 50% 50%, rgba(6,182,212,0.04) 0%, transparent 70%);
        pointer-events: none;
        z-index: 0;
    }

    /* ── Navbar ── */
    .navbar {
        position: sticky; top: 0; z-index: 100;
        display: flex; align-items: center; justify-content: space-between;
        padding: 0 40px;
        height: 64px;
        background: rgba(5,8,24,0.92);
        backdrop-filter: blur(20px);
        border-bottom: 1px solid var(--border);
    }
    .nav-logo {
        display: flex; align-items: center; gap: 10px;
        font-size: 1.25rem; font-weight: 800;
        background: linear-gradient(135deg, var(--cyan), var(--blue), var(--purple));
        -webkit-background-clip: text; -webkit-text-fill-color: transparent;
        letter-spacing: -0.5px;
    }
    .nav-logo .shield { font-size: 1.4rem; }
    .nav-links { display: flex; gap: 28px; }
    .nav-links a {
        color: var(--muted); text-decoration: none; font-size: 0.9rem; font-weight: 500;
        transition: color 0.2s;
    }
    .nav-links a:hover { color: var(--cyan); }
    .nav-badge {
        padding: 5px 14px; border-radius: 20px; font-size: 0.75rem; font-weight: 700;
        letter-spacing: 0.5px; text-transform: uppercase;
    }
    .badge-blue { background: rgba(59,130,246,0.15); color: var(--blue); border: 1px solid rgba(59,130,246,0.35); }
    .badge-green { background: rgba(16,185,129,0.15); color: var(--green); border: 1px solid rgba(16,185,129,0.35); }
    .badge-healthy { background: rgba(16,185,129,0.15); color: var(--green); border: 1px solid rgba(16,185,129,0.35); }
    .badge-danger { background: rgba(239,68,68,0.15); color: var(--red); border: 1px solid rgba(239,68,68,0.35); }

    /* ── Hero ── */
    .hero {
        position: relative; z-index: 1;
        padding: 72px 40px 48px;
        text-align: center;
    }
    .hero-eyebrow {
        display: inline-flex; align-items: center; gap: 8px;
        padding: 6px 16px; border-radius: 20px; margin-bottom: 24px;
        background: rgba(59,130,246,0.1); border: 1px solid rgba(59,130,246,0.25);
        font-size: 0.8rem; font-weight: 600; color: var(--cyan); letter-spacing: 1px; text-transform: uppercase;
    }
    .hero h1 {
        font-size: clamp(2rem, 5vw, 3.5rem);
        font-weight: 900; line-height: 1.1; letter-spacing: -1px;
        margin-bottom: 16px;
        background: linear-gradient(135deg, #fff 0%, var(--cyan) 50%, var(--blue) 100%);
        -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .hero p {
        color: var(--muted); font-size: 1.1rem; max-width: 600px; margin: 0 auto 32px;
        line-height: 1.7;
    }

    /* ── Section ── */
    .section { position: relative; z-index: 1; padding: 48px 40px; max-width: 1280px; margin: 0 auto; }
    .section-title {
        font-size: 1.3rem; font-weight: 700; margin-bottom: 6px; color: var(--text);
        display: flex; align-items: center; gap: 10px;
    }
    .section-title .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--cyan); display: inline-block; }
    .section-sub { color: var(--muted); font-size: 0.9rem; margin-bottom: 28px; }

    /* ── Glass Card ── */
    .glass-card {
        background: var(--glass);
        border: 1px solid var(--border);
        border-radius: 16px;
        backdrop-filter: blur(20px);
        transition: border-color 0.3s, transform 0.3s, box-shadow 0.3s;
    }
    .glass-card:hover {
        border-color: rgba(6,182,212,0.3);
        transform: translateY(-4px);
        box-shadow: 0 20px 60px rgba(6,182,212,0.08);
    }

    /* ── Movie Grid ── */
    .movies-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
        gap: 20px;
    }
    .movie-card {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 12px;
        overflow: hidden;
        cursor: pointer;
        transition: transform 0.3s, box-shadow 0.3s, border-color 0.3s;
    }
    .movie-card:hover {
        transform: translateY(-8px) scale(1.02);
        box-shadow: 0 24px 48px rgba(0,0,0,0.5);
        border-color: rgba(6,182,212,0.4);
    }
    .movie-thumb {
        height: 130px;
        display: flex; align-items: center; justify-content: center;
        font-size: 3.5rem;
        position: relative;
    }
    .movie-thumb-v1 { background: linear-gradient(135deg, #0f172a, #1e3a5f, #0d2137); }
    .movie-info { padding: 14px; }
    .movie-title { font-weight: 700; font-size: 0.95rem; margin-bottom: 6px; }
    .movie-meta { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
    .movie-genre { font-size: 0.75rem; color: var(--cyan); font-weight: 500; }
    .movie-rating { font-size: 0.75rem; color: var(--gold); font-weight: 600; }
    .movie-year { font-size: 0.75rem; color: var(--muted); }
    .play-btn {
        display: inline-flex; align-items: center; gap: 6px;
        margin-top: 10px; padding: 6px 14px; border-radius: 6px;
        background: linear-gradient(135deg, var(--blue), var(--cyan));
        color: #fff; font-size: 0.78rem; font-weight: 600;
        border: none; cursor: pointer; text-decoration: none;
        transition: opacity 0.2s;
    }
    .play-btn:hover { opacity: 0.85; }

    /* ── Metrics Grid ── */
    .metrics-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
        gap: 16px;
    }
    .metric-card {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 12px;
        padding: 20px;
        text-align: center;
        transition: border-color 0.3s, transform 0.3s;
    }
    .metric-card:hover { border-color: rgba(6,182,212,0.3); transform: translateY(-3px); }
    .metric-value { font-size: 1.8rem; font-weight: 800; margin-bottom: 4px; }
    .metric-label { font-size: 0.8rem; color: var(--muted); font-weight: 500; }
    .metric-sub { font-size: 0.75rem; margin-top: 4px; }
    .val-green { color: var(--green); }
    .val-blue  { color: var(--blue); }
    .val-cyan  { color: var(--cyan); }
    .val-gold  { color: var(--gold); }
    .val-red   { color: var(--red); }
    .val-white { color: #fff; }

    /* ── DevOps Panel ── */
    .devops-panel {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 16px;
        padding: 28px;
    }
    .panel-title {
        font-size: 1rem; font-weight: 700; margin-bottom: 20px;
        color: var(--cyan);
        display: flex; align-items: center; gap: 8px;
    }
    .panel-rows { display: flex; flex-direction: column; gap: 12px; }
    .panel-row {
        display: flex; justify-content: space-between; align-items: center;
        padding: 10px 0; border-bottom: 1px solid var(--border);
    }
    .panel-row:last-child { border-bottom: none; }
    .panel-key { color: var(--muted); font-size: 0.88rem; font-weight: 500; }
    .panel-val { font-size: 0.88rem; font-weight: 700; }

    /* ── Status indicator ── */
    .status-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; margin-right: 6px; }
    .dot-green { background: var(--green); box-shadow: 0 0 8px var(--green); animation: pulse 2s infinite; }
    .dot-blue  { background: var(--blue);  box-shadow: 0 0 8px var(--blue);  animation: pulse 2s infinite; }
    .dot-red   { background: var(--red);   box-shadow: 0 0 8px var(--red);   animation: pulse 2s infinite; }

    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.4; }
    }

    /* ── Tag Chip ── */
    .chip {
        display: inline-flex; align-items: center; gap: 4px;
        padding: 3px 10px; border-radius: 20px;
        font-size: 0.72rem; font-weight: 600; letter-spacing: 0.3px;
    }
    .chip-green { background: rgba(16,185,129,0.12); color: var(--green); border: 1px solid rgba(16,185,129,0.3); }
    .chip-blue  { background: rgba(59,130,246,0.12);  color: var(--blue);  border: 1px solid rgba(59,130,246,0.3); }
    .chip-red   { background: rgba(239,68,68,0.12);   color: var(--red);   border: 1px solid rgba(239,68,68,0.3); }
    .chip-cyan  { background: rgba(6,182,212,0.12);   color: var(--cyan);  border: 1px solid rgba(6,182,212,0.3); }

    /* ── Footer ── */
    .footer {
        text-align: center; padding: 40px;
        color: var(--muted); font-size: 0.82rem;
        border-top: 1px solid var(--border);
        position: relative; z-index: 1;
    }
    .footer span { color: var(--cyan); }

    /* ── Watch page ── */
    .player-wrapper {
        max-width: 860px; margin: 48px auto; padding: 0 40px;
        position: relative; z-index: 1;
    }
    .player-screen {
        aspect-ratio: 16/9;
        background: linear-gradient(135deg, #050818, #0a1628, #0d2137);
        border-radius: 16px;
        border: 1px solid var(--border);
        display: flex; flex-direction: column; align-items: center; justify-content: center;
        gap: 16px; margin-bottom: 28px;
        position: relative; overflow: hidden;
    }
    .player-screen::before {
        content: '';
        position: absolute; inset: 0;
        background: radial-gradient(ellipse at center, rgba(59,130,246,0.06) 0%, transparent 70%);
    }
    .player-icon { font-size: 4rem; }
    .player-title { font-size: 1.5rem; font-weight: 800; color: #fff; }
    .player-sub { color: var(--cyan); font-size: 0.95rem; }
    .player-stats {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
        gap: 16px;
    }
    .player-stat-card {
        background: var(--card); border: 1px solid var(--border); border-radius: 12px;
        padding: 16px 20px;
        display: flex; align-items: center; gap: 14px;
    }
    .stat-icon { font-size: 1.6rem; }
    .stat-text-label { font-size: 0.78rem; color: var(--muted); font-weight: 500; }
    .stat-text-value { font-size: 1rem; font-weight: 700; color: var(--green); }
"""

# ─── HTML Template Builder ─────────────────────────────────────────────────────
def page(title, body, extra_css=""):
    """Wraps body content in the full HTML shell with navbar and footer."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <meta name="description" content="StreamShield v1 — Stable Blue Production Streaming Platform. Zero-Downtime Release Simulator."/>
  <title>{title} | StreamShield Simulator</title>
  <style>
    {SHARED_CSS}
    {extra_css}
  </style>
</head>
<body>

<!-- ── Navbar ── -->
<nav class="navbar">
  <div class="nav-logo">
    <span class="shield">🛡️</span>
    <span>StreamShield</span>
  </div>
  <div class="nav-links">
    <a href="/">Home</a>
    <a href="/movies">Movies</a>
    <a href="/watch">Watch</a>
    <a href="/health">Health</a>
    <a href="/metrics">Metrics</a>
  </div>
  <span class="nav-badge badge-blue">v1 · BLUE · STABLE</span>
</nav>

{body}

<!-- ── Footer ── -->
<footer class="footer">
  <p>🛡️ <span>StreamShield Simulator</span> — Phase 1 · v1 Blue Environment</p>
  <p style="margin-top:6px;">Safe releases for high-traffic streaming platforms</p>
</footer>

</body>
</html>"""


# =============================================================================
# ROUTE: / — Homepage
# =============================================================================
@app.route("/")
def homepage():
    """
    Main homepage for v1.
    Shows: streaming UI, DevOps status panel, metrics cards.
    """
    start = time.time()

    # ── Movie Cards HTML ──────────────────────────────────────────────────────
    movie_cards_html = ""
    for m in MOVIES:
        movie_cards_html += f"""
        <div class="movie-card">
          <div class="movie-thumb movie-thumb-v1">
            <span>{m['emoji']}</span>
          </div>
          <div class="movie-info">
            <div class="movie-title">{m['title']}</div>
            <div class="movie-meta">
              <span class="movie-genre">{m['genre']}</span>
              <span class="movie-rating">★ {m['rating']}</span>
              <span class="movie-year">{m['year']}</span>
            </div>
            <a href="/watch" class="play-btn">▶ Play</a>
          </div>
        </div>"""

    body = f"""
    <!-- ── Hero ── -->
    <div class="hero">
      <div class="hero-eyebrow">🛡️ DEVOPS RELEASE SIMULATOR · PHASE 1</div>
      <h1>StreamShield v1<br>Stable Streaming Platform</h1>
      <p>This is the <strong>current production version</strong> serving users safely.<br>
         The Blue environment — battle-tested, zero failures, fully monitored.</p>
      <div style="display:flex; justify-content:center; gap:12px; flex-wrap:wrap; margin-top:8px;">
        <span class="chip chip-blue">🔵 BLUE ENVIRONMENT — STABLE</span>
        <span class="chip chip-green"><span class="status-dot dot-green"></span>ALL SYSTEMS HEALTHY</span>
        <span class="chip chip-cyan">100% TRAFFIC LIVE</span>
      </div>
    </div>

    <!-- ── Release Mode Explainer ── -->
    <div class="section" style="padding-top:0;">
      <div style="display:grid; grid-template-columns:1fr 1fr; gap:20px; margin-bottom:48px;">

        <!-- Unsafe Mode Card -->
        <div class="glass-card" style="padding:28px; border-color:rgba(239,68,68,0.25);">
          <div style="display:flex; align-items:center; gap:10px; margin-bottom:14px;">
            <span style="font-size:1.8rem;">⚠️</span>
            <div>
              <div style="font-weight:800; font-size:1.05rem; color:var(--red);">Unsafe Rollout Mode</div>
              <div style="font-size:0.78rem; color:var(--muted);">What happens WITHOUT smart release</div>
            </div>
          </div>
          <p style="font-size:0.85rem; color:var(--muted); line-height:1.7; margin-bottom:16px;">
            Direct release of v2 to <strong style="color:var(--red);">100% of users</strong> with no safety net.
            Bugs reach everyone instantly. No rollback. No health checks.
          </p>
          <div style="display:flex; flex-direction:column; gap:8px;">
            <div style="display:flex; justify-content:space-between; font-size:0.82rem; padding:6px 0; border-bottom:1px solid var(--border);">
              <span style="color:var(--muted);">Traffic to v2</span><span style="color:var(--red); font-weight:700;">100% (all users)</span>
            </div>
            <div style="display:flex; justify-content:space-between; font-size:0.82rem; padding:6px 0; border-bottom:1px solid var(--border);">
              <span style="color:var(--muted);">Internal QA</span><span style="color:var(--red); font-weight:700;">Skipped ✗</span>
            </div>
            <div style="display:flex; justify-content:space-between; font-size:0.82rem; padding:6px 0; border-bottom:1px solid var(--border);">
              <span style="color:var(--muted);">Canary Rollout</span><span style="color:var(--red); font-weight:700;">Disabled ✗</span>
            </div>
            <div style="display:flex; justify-content:space-between; font-size:0.82rem; padding:6px 0;">
              <span style="color:var(--muted);">Rollback</span><span style="color:var(--red); font-weight:700;">Not Available ✗</span>
            </div>
          </div>
          <div style="margin-top:16px; padding:10px 14px; background:rgba(239,68,68,0.08); border-radius:8px; border:1px solid rgba(239,68,68,0.2); font-size:0.82rem; color:var(--red);">
            💀 Risk: <strong>CRITICAL</strong> — Users experience outage
          </div>
        </div>

        <!-- Smart Mode Card -->
        <div class="glass-card" style="padding:28px; border-color:rgba(16,185,129,0.25);">
          <div style="display:flex; align-items:center; gap:10px; margin-bottom:14px;">
            <span style="font-size:1.8rem;">✅</span>
            <div>
              <div style="font-weight:800; font-size:1.05rem; color:var(--green);">Smart Rollout Mode</div>
              <div style="font-size:0.78rem; color:var(--muted);">DevOps best practice release strategy</div>
            </div>
          </div>
          <p style="font-size:0.85rem; color:var(--muted); line-height:1.7; margin-bottom:16px;">
            v2 is tested by QA first, then gradually released to <strong style="color:var(--green);">10% of users</strong>.
            Health is monitored continuously. Automatic rollback if issues detected.
          </p>
          <div style="display:flex; flex-direction:column; gap:8px;">
            <div style="display:flex; justify-content:space-between; font-size:0.82rem; padding:6px 0; border-bottom:1px solid var(--border);">
              <span style="color:var(--muted);">Traffic to v2</span><span style="color:var(--green); font-weight:700;">10% (canary users)</span>
            </div>
            <div style="display:flex; justify-content:space-between; font-size:0.82rem; padding:6px 0; border-bottom:1px solid var(--border);">
              <span style="color:var(--muted);">Internal QA</span><span style="color:var(--green); font-weight:700;">Enabled ✓</span>
            </div>
            <div style="display:flex; justify-content:space-between; font-size:0.82rem; padding:6px 0; border-bottom:1px solid var(--border);">
              <span style="color:var(--muted);">Canary Rollout</span><span style="color:var(--green); font-weight:700;">Enabled ✓</span>
            </div>
            <div style="display:flex; justify-content:space-between; font-size:0.82rem; padding:6px 0;">
              <span style="color:var(--muted);">Rollback</span><span style="color:var(--green); font-weight:700;">Ready ✓</span>
            </div>
          </div>
          <div style="margin-top:16px; padding:10px 14px; background:rgba(16,185,129,0.08); border-radius:8px; border:1px solid rgba(16,185,129,0.2); font-size:0.82rem; color:var(--green);">
            🛡️ Risk: <strong>LOW</strong> — 90% users protected on v1
          </div>
        </div>
      </div>

      <!-- ── Technical Metrics ── -->
      <div class="section-title"><span class="dot"></span> Live Technical Metrics · v1 Blue</div>
      <div class="section-sub">Real-time health indicators for the stable production environment</div>
      <div class="metrics-grid" style="margin-bottom:48px;">
        <div class="metric-card">
          <div class="metric-value val-cyan">100%</div>
          <div class="metric-label">Traffic Split</div>
          <div class="metric-sub" style="color:var(--muted);">All traffic on v1</div>
        </div>
        <div class="metric-card">
          <div class="metric-value val-green">0.4%</div>
          <div class="metric-label">Error Rate</div>
          <div class="metric-sub" style="color:var(--green);">✓ Below threshold</div>
        </div>
        <div class="metric-card">
          <div class="metric-value val-blue">180ms</div>
          <div class="metric-label">Playback Latency</div>
          <div class="metric-sub" style="color:var(--green);">✓ Optimal</div>
        </div>
        <div class="metric-card">
          <div class="metric-value val-green">96/100</div>
          <div class="metric-label">Health Score</div>
          <div class="metric-sub" style="color:var(--green);">✓ Excellent</div>
        </div>
        <div class="metric-card">
          <div class="metric-value val-green">NO</div>
          <div class="metric-label">Rollback Required</div>
          <div class="metric-sub" style="color:var(--green);">✓ All stable</div>
        </div>
      </div>

      <!-- ── DevOps Status Panel ── -->
      <div class="section-title" style="margin-bottom:8px;"><span class="dot"></span> DevOps Status Panel</div>
      <div class="section-sub">Current deployment details for the Blue production environment</div>
      <div class="devops-panel" style="margin-bottom:48px;">
        <div class="panel-title">⚙️ Deployment Status — v1 Blue Environment</div>
        <div class="panel-rows">
          <div class="panel-row"><span class="panel-key">Active Version</span><span class="panel-val val-blue">v1 (Blue)</span></div>
          <div class="panel-row"><span class="panel-key">Environment</span><span class="panel-val val-blue">Blue 🔵</span></div>
          <div class="panel-row"><span class="panel-key">Traffic Strategy</span><span class="panel-val val-cyan">100% stable — no canary</span></div>
          <div class="panel-row"><span class="panel-key">Error Rate</span><span class="panel-val val-green">0.4% ✓</span></div>
          <div class="panel-row"><span class="panel-key">Avg Latency</span><span class="panel-val val-blue">180ms</span></div>
          <div class="panel-row"><span class="panel-key">Health Score</span><span class="panel-val val-green">96 / 100 ✓</span></div>
          <div class="panel-row"><span class="panel-key">Rollback Required</span><span class="panel-val val-green">No</span></div>
          <div class="panel-row"><span class="panel-key">Pod Health</span><span class="panel-val"><span class="status-dot dot-green"></span>All pods healthy</span></div>
        </div>
      </div>

      <!-- ── Movie Grid ── -->
      <div class="section-title"><span class="dot"></span> Featured Titles</div>
      <div class="section-sub">Premium content available on the stable platform</div>
      <div class="movies-grid">
        {movie_cards_html}
      </div>
    </div>
    """

    elapsed = time.time() - start
    request_latency.labels(version="v1", endpoint="/").observe(elapsed)
    http_requests_total.labels(version="v1", endpoint="/", status="200").inc()
    return page("Home", body)


# =============================================================================
# ROUTE: /health — Health Check (JSON)
# =============================================================================
@app.route("/health")
def health():
    """Returns health status as JSON — used by load balancers and monitoring tools."""
    http_requests_total.labels(version="v1", endpoint="/health", status="200").inc()
    return jsonify({
        "status": "healthy",
        "version": "v1",
        "environment": "blue",
        "message": "Stable production version is healthy",
        "metrics": {
            "error_rate": "0.4%",
            "latency_avg": "180ms",
            "health_score": "96/100"
        }
    })


# =============================================================================
# ROUTE: /movies — Movie List (JSON)
# =============================================================================
@app.route("/movies")
def movies():
    """Returns the JSON list of available movies."""
    http_requests_total.labels(version="v1", endpoint="/movies", status="200").inc()
    return jsonify({
        "version": "v1",
        "environment": "blue",
        "total": len(MOVIES),
        "movies": MOVIES
    })


# =============================================================================
# ROUTE: /watch — Stable Watch Page
# =============================================================================
@app.route("/watch")
def watch():
    """
    Stable video player page — v1 always delivers smooth playback.
    No chaos mode in v1.
    """
    start = time.time()

    body = """
    <div class="player-wrapper">
      <div style="margin-bottom:20px;">
        <a href="/" style="color:var(--cyan); text-decoration:none; font-size:0.9rem;">← Back to Home</a>
      </div>

      <div style="margin-bottom:20px;">
        <h2 style="font-size:1.5rem; font-weight:800; margin-bottom:4px;">Stable Player <span style="color:var(--blue);">v1</span></h2>
        <div style="display:flex; gap:10px; flex-wrap:wrap;">
          <span class="chip chip-blue">🔵 BLUE ENVIRONMENT</span>
          <span class="chip chip-green">● STABLE PLAYBACK</span>
        </div>
      </div>

      <!-- Player Screen -->
      <div class="player-screen">
        <div class="player-icon">▶️</div>
        <div class="player-title">Stable Player v1</div>
        <div class="player-sub">Smooth, reliable streaming — production quality</div>
        <div style="position:absolute; bottom:20px; left:0; right:0; padding:0 28px;">
          <div style="height:4px; background:var(--border); border-radius:2px; overflow:hidden;">
            <div style="width:35%; height:100%; background:linear-gradient(90deg, var(--blue), var(--cyan)); border-radius:2px;"></div>
          </div>
          <div style="display:flex; justify-content:space-between; margin-top:6px; font-size:0.75rem; color:var(--muted);">
            <span>0:47</span><span>2:15:00</span>
          </div>
        </div>
      </div>

      <!-- Stats -->
      <div class="player-stats">
        <div class="player-stat-card">
          <span class="stat-icon">🎬</span>
          <div>
            <div class="stat-text-label">Playback Status</div>
            <div class="stat-text-value">Smooth ✓</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">🎯</span>
          <div>
            <div class="stat-text-label">Video Quality</div>
            <div class="stat-text-value">Full HD 1080p</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">⚡</span>
          <div>
            <div class="stat-text-label">Buffering</div>
            <div class="stat-text-value">None ✓</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">📡</span>
          <div>
            <div class="stat-text-label">Stream Latency</div>
            <div class="stat-text-value">180ms</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">🛡️</span>
          <div>
            <div class="stat-text-label">Player Engine</div>
            <div class="stat-text-value">Stable v1</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">✅</span>
          <div>
            <div class="stat-text-label">Error Rate</div>
            <div class="stat-text-value">0.4% (nominal)</div>
          </div>
        </div>
      </div>

      <div style="margin-top:24px; padding:16px 20px; background:rgba(16,185,129,0.06); border:1px solid rgba(16,185,129,0.2); border-radius:12px;">
        <div style="font-weight:700; color:var(--green); margin-bottom:6px;">✅ v1 Production Guarantee</div>
        <div style="font-size:0.85rem; color:var(--muted); line-height:1.6;">
          This route always works in v1. There is no chaos mode here.
          This is the stable Blue environment — safe, monitored, and battle-tested.
        </div>
      </div>
    </div>
    """

    elapsed = time.time() - start
    request_latency.labels(version="v1", endpoint="/watch").observe(elapsed)
    http_requests_total.labels(version="v1", endpoint="/watch", status="200").inc()
    return page("Watch", body)


# =============================================================================
# ROUTE: /release-mode — Release Mode Info (JSON)
# =============================================================================
@app.route("/release-mode")
def release_mode():
    """Returns JSON explaining v1's stable release mode."""
    http_requests_total.labels(version="v1", endpoint="/release-mode", status="200").inc()
    return jsonify({
        "mode": "stable",
        "version": "v1",
        "environment": "blue",
        "traffic_strategy": "100% traffic to v1",
        "risk": "low",
        "canary_enabled": False,
        "rollback_required": False,
        "health_score": "96/100",
        "description": (
            "v1 is the stable production environment. All user traffic goes through v1. "
            "This is the 'Blue' environment in a Blue-Green deployment strategy."
        )
    })


# =============================================================================
# ROUTE: /metrics — Prometheus Metrics
# =============================================================================
@app.route("/metrics")
def metrics():
    """
    Exposes Prometheus-compatible metrics.
    Scraped by Prometheus server in Phase 2 (Kubernetes setup).
    """
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


# =============================================================================
# Main Entry Point
# =============================================================================
if __name__ == "__main__":
    # host="0.0.0.0" makes Flask accessible outside the container (Docker requirement)
    print("🛡️  StreamShield v1 — Stable Blue Environment")
    print("🌐  Running on http://0.0.0.0:5000")
    print("📊  Metrics at http://0.0.0.0:5000/metrics")
    app.run(host="0.0.0.0", port=5000, debug=False)
