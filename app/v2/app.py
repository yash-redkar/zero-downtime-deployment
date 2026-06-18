# =============================================================================
# StreamShield v2 — Smart Release Simulator (Green Environment)
# =============================================================================
# This represents the NEW release candidate being tested before full rollout.
# It features:
#   - A mode switcher: Unsafe Rollout vs Smart Rollout (DevOps simulator)
#   - Smart video player with 4K adaptive streaming UI
#   - Trending engine with personalized recommendations
#   - Chaos mode simulation for bad release testing
#   - Prometheus metrics including chaos_mode gauge
# =============================================================================

import time
import random
from flask import Flask, jsonify, Response, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# ─── Flask App Setup ─────────────────────────────────────────────────────────
app = Flask(__name__)

# ─── Global Chaos Mode State ──────────────────────────────────────────────────
# When chaos_mode is True, /watch simulates a buggy bad release:
#   - random HTTP 500 errors
#   - simulated latency (time.sleep)
#   - increased playback failure metric
chaos_mode = False

# ─── Prometheus Metrics ───────────────────────────────────────────────────────
http_requests_total = Counter(
    'streamshield_http_requests_total',
    'Total HTTP requests to StreamShield',
    ['version', 'endpoint', 'status']
)

request_latency = Histogram(
    'streamshield_request_latency_seconds',
    'HTTP request latency in seconds',
    ['version', 'endpoint']
)

playback_failures_total = Counter(
    'streamshield_playback_failures_total',
    'Total playback failures',
    ['version']
)

# Gauge for chaos mode — 1.0 = chaos ON, 0.0 = chaos OFF
chaos_mode_gauge = Gauge(
    'streamshield_chaos_mode',
    'Whether chaos mode (bad release simulation) is currently active'
)

# ─── Movie / Trending Data ────────────────────────────────────────────────────
MOVIES = [
    {"id": 1, "title": "Cyber Heist",         "genre": "Thriller",    "rating": 8.4, "year": 2024, "duration": "2h 15m", "emoji": "🔐", "new": False},
    {"id": 2, "title": "Mumbai Nights",        "genre": "Drama",       "rating": 8.1, "year": 2024, "duration": "2h 05m", "emoji": "🌆", "new": False},
    {"id": 3, "title": "Live Sports Final",    "genre": "Sports",      "rating": 9.2, "year": 2024, "duration": "3h 00m", "emoji": "🏆", "new": True},
    {"id": 4, "title": "DevOps Documentary",   "genre": "Documentary", "rating": 8.7, "year": 2024, "duration": "1h 45m", "emoji": "🚀", "new": False},
    {"id": 5, "title": "Space Wars",           "genre": "Sci-Fi",      "rating": 8.9, "year": 2024, "duration": "2h 30m", "emoji": "🌌", "new": True},
    {"id": 6, "title": "AI Takeover",          "genre": "Sci-Fi",      "rating": 9.1, "year": 2025, "duration": "2h 10m", "emoji": "🤖", "new": True},
]

TRENDING = [
    {"rank": 1, "title": "Live Cricket Final",  "genre": "Sports",      "emoji": "🏏", "viewers": "4.2M", "trend": "🔥"},
    {"rank": 2, "title": "Cyber Heist",         "genre": "Thriller",    "emoji": "🔐", "viewers": "2.8M", "trend": "📈"},
    {"rank": 3, "title": "Mumbai Nights",       "genre": "Drama",       "emoji": "🌆", "viewers": "2.1M", "trend": "📈"},
    {"rank": 4, "title": "DevOps Documentary",  "genre": "Documentary", "emoji": "🚀", "viewers": "1.6M", "trend": "🔥"},
    {"rank": 5, "title": "Space Wars",          "genre": "Sci-Fi",      "emoji": "🌌", "viewers": "1.4M", "trend": "📈"},
    {"rank": 6, "title": "AI Takeover",         "genre": "Sci-Fi",      "emoji": "🤖", "viewers": "3.7M", "trend": "🔥"},
]

# ─── Shared CSS ────────────────────────────────────────────────────────────────
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

    body::before {
        content: '';
        position: fixed;
        inset: 0;
        background:
            radial-gradient(ellipse 80% 50% at 20% 10%, rgba(139,92,246,0.09) 0%, transparent 60%),
            radial-gradient(ellipse 60% 40% at 80% 80%, rgba(16,185,129,0.07) 0%, transparent 60%),
            radial-gradient(ellipse 50% 60% at 50% 50%, rgba(6,182,212,0.04) 0%, transparent 70%);
        pointer-events: none;
        z-index: 0;
    }

    /* ── Navbar ── */
    .navbar {
        position: sticky; top: 0; z-index: 100;
        display: flex; align-items: center; justify-content: space-between;
        padding: 0 40px; height: 64px;
        background: rgba(5,8,24,0.92);
        backdrop-filter: blur(20px);
        border-bottom: 1px solid var(--border);
    }
    .nav-logo {
        display: flex; align-items: center; gap: 10px;
        font-size: 1.25rem; font-weight: 800;
        background: linear-gradient(135deg, var(--purple), var(--cyan), var(--green));
        -webkit-background-clip: text; -webkit-text-fill-color: transparent;
        letter-spacing: -0.5px;
    }
    .nav-links { display: flex; gap: 24px; }
    .nav-links a {
        color: var(--muted); text-decoration: none; font-size: 0.88rem; font-weight: 500;
        transition: color 0.2s;
    }
    .nav-links a:hover { color: var(--purple); }
    .nav-badge {
        padding: 5px 14px; border-radius: 20px; font-size: 0.75rem; font-weight: 700;
        letter-spacing: 0.5px; text-transform: uppercase;
    }
    .badge-green  { background: rgba(16,185,129,0.15);  color: var(--green);  border: 1px solid rgba(16,185,129,0.35); }
    .badge-purple { background: rgba(139,92,246,0.15);  color: var(--purple); border: 1px solid rgba(139,92,246,0.35); }
    .badge-danger { background: rgba(239,68,68,0.15);   color: var(--red);    border: 1px solid rgba(239,68,68,0.35); }

    /* ── Hero ── */
    .hero {
        position: relative; z-index: 1;
        padding: 72px 40px 48px;
        text-align: center;
    }
    .hero-eyebrow {
        display: inline-flex; align-items: center; gap: 8px;
        padding: 6px 16px; border-radius: 20px; margin-bottom: 24px;
        background: rgba(139,92,246,0.1); border: 1px solid rgba(139,92,246,0.25);
        font-size: 0.8rem; font-weight: 600; color: var(--purple);
        letter-spacing: 1px; text-transform: uppercase;
    }
    .hero h1 {
        font-size: clamp(2rem, 5vw, 3.5rem);
        font-weight: 900; line-height: 1.1; letter-spacing: -1px;
        margin-bottom: 16px;
        background: linear-gradient(135deg, #fff 0%, var(--purple) 45%, var(--green) 100%);
        -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .hero p { color: var(--muted); font-size: 1.1rem; max-width: 640px; margin: 0 auto 32px; line-height: 1.7; }

    /* ── Section ── */
    .section { position: relative; z-index: 1; padding: 48px 40px; max-width: 1280px; margin: 0 auto; }
    .section-title {
        font-size: 1.3rem; font-weight: 700; margin-bottom: 6px;
        display: flex; align-items: center; gap: 10px;
    }
    .section-title .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--purple); display: inline-block; }
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
        border-color: rgba(139,92,246,0.3);
        transform: translateY(-4px);
        box-shadow: 0 20px 60px rgba(139,92,246,0.08);
    }

    /* ── Mode Switcher ── */
    .mode-switcher {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 24px;
        margin-bottom: 48px;
    }
    .mode-card {
        border-radius: 20px;
        padding: 32px;
        cursor: pointer;
        transition: all 0.35s cubic-bezier(0.4,0,0.2,1);
        position: relative;
        overflow: hidden;
    }
    .mode-card::before {
        content: '';
        position: absolute; inset: 0; opacity: 0;
        transition: opacity 0.3s;
    }
    .mode-card.unsafe {
        background: rgba(239,68,68,0.06);
        border: 2px solid rgba(239,68,68,0.2);
    }
    .mode-card.unsafe::before { background: radial-gradient(circle at 50% 0%, rgba(239,68,68,0.12), transparent 70%); }
    .mode-card.unsafe.active, .mode-card.unsafe:hover {
        border-color: rgba(239,68,68,0.6);
        box-shadow: 0 0 40px rgba(239,68,68,0.15), inset 0 0 40px rgba(239,68,68,0.04);
    }
    .mode-card.unsafe.active::before, .mode-card.unsafe:hover::before { opacity: 1; }

    .mode-card.smart {
        background: rgba(16,185,129,0.06);
        border: 2px solid rgba(16,185,129,0.2);
    }
    .mode-card.smart::before { background: radial-gradient(circle at 50% 0%, rgba(16,185,129,0.12), transparent 70%); }
    .mode-card.smart.active, .mode-card.smart:hover {
        border-color: rgba(16,185,129,0.6);
        box-shadow: 0 0 40px rgba(16,185,129,0.15), inset 0 0 40px rgba(16,185,129,0.04);
    }
    .mode-card.smart.active::before, .mode-card.smart:hover::before { opacity: 1; }

    .mode-card.active { transform: translateY(-6px); }

    .mode-icon { font-size: 2.5rem; margin-bottom: 14px; }
    .mode-title { font-size: 1.3rem; font-weight: 800; margin-bottom: 8px; }
    .mode-desc { font-size: 0.88rem; color: var(--muted); line-height: 1.6; margin-bottom: 20px; }
    .mode-metrics { display: flex; flex-direction: column; gap: 8px; }
    .mode-metric-row {
        display: flex; justify-content: space-between; align-items: center;
        font-size: 0.83rem; padding: 7px 0; border-bottom: 1px solid var(--border);
    }
    .mode-metric-row:last-child { border-bottom: none; }
    .mode-metric-key { color: var(--muted); }
    .mode-badge {
        display: inline-flex; align-items: center; gap: 4px;
        padding: 2px 10px; border-radius: 12px; font-size: 0.72rem; font-weight: 700;
    }
    .mb-green  { background: rgba(16,185,129,0.12);  color: var(--green);  border: 1px solid rgba(16,185,129,0.3); }
    .mb-red    { background: rgba(239,68,68,0.12);   color: var(--red);    border: 1px solid rgba(239,68,68,0.3); }
    .mb-yellow { background: rgba(245,158,11,0.12);  color: var(--gold);   border: 1px solid rgba(245,158,11,0.3); }
    .mb-cyan   { background: rgba(6,182,212,0.12);   color: var(--cyan);   border: 1px solid rgba(6,182,212,0.3); }
    .mb-purple { background: rgba(139,92,246,0.12);  color: var(--purple); border: 1px solid rgba(139,92,246,0.3); }

    .mode-select-btn {
        margin-top: 20px; width: 100%;
        padding: 12px; border-radius: 10px;
        font-size: 0.9rem; font-weight: 700;
        border: none; cursor: pointer;
        transition: all 0.25s;
    }
    .unsafe .mode-select-btn { background: rgba(239,68,68,0.15); color: var(--red); border: 1px solid rgba(239,68,68,0.3); }
    .unsafe .mode-select-btn:hover { background: var(--red); color: #fff; }
    .smart .mode-select-btn  { background: rgba(16,185,129,0.15); color: var(--green); border: 1px solid rgba(16,185,129,0.3); }
    .smart .mode-select-btn:hover  { background: var(--green); color: #fff; }

    /* ── Mode Info Panel (shown after selection) ── */
    #mode-info-panel {
        display: none;
        margin-top: 24px;
        padding: 24px 28px;
        border-radius: 16px;
        animation: fadeIn 0.4s ease;
    }
    @keyframes fadeIn { from { opacity:0; transform: translateY(10px); } to { opacity:1; transform: translateY(0); } }
    #mode-info-panel.show { display: block; }

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
        position: relative;
    }
    .movie-card:hover {
        transform: translateY(-8px) scale(1.02);
        box-shadow: 0 24px 48px rgba(0,0,0,0.5);
        border-color: rgba(139,92,246,0.4);
    }
    .movie-thumb {
        height: 130px;
        display: flex; align-items: center; justify-content: center;
        font-size: 3.5rem; position: relative;
    }
    .movie-thumb-v2 { background: linear-gradient(135deg, #0f172a, #1e1040, #0f0d2d); }
    .new-badge {
        position: absolute; top: 8px; right: 8px;
        padding: 2px 8px; border-radius: 6px;
        background: var(--purple); color: #fff;
        font-size: 0.65rem; font-weight: 700; text-transform: uppercase;
    }
    .movie-info { padding: 14px; }
    .movie-title { font-weight: 700; font-size: 0.95rem; margin-bottom: 6px; }
    .movie-meta { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
    .movie-genre { font-size: 0.75rem; color: var(--purple); font-weight: 500; }
    .movie-rating { font-size: 0.75rem; color: var(--gold); font-weight: 600; }
    .movie-year { font-size: 0.75rem; color: var(--muted); }
    .play-btn {
        display: inline-flex; align-items: center; gap: 6px;
        margin-top: 10px; padding: 6px 14px; border-radius: 6px;
        background: linear-gradient(135deg, var(--purple), var(--blue));
        color: #fff; font-size: 0.78rem; font-weight: 600;
        border: none; cursor: pointer; text-decoration: none;
        transition: opacity 0.2s;
    }
    .play-btn:hover { opacity: 0.85; }

    /* ── Metrics Grid ── */
    .metrics-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 16px; }
    .metric-card {
        background: var(--card); border: 1px solid var(--border); border-radius: 12px;
        padding: 20px; text-align: center;
        transition: border-color 0.3s, transform 0.3s;
    }
    .metric-card:hover { border-color: rgba(139,92,246,0.3); transform: translateY(-3px); }
    .metric-value { font-size: 1.8rem; font-weight: 800; margin-bottom: 4px; }
    .metric-label { font-size: 0.8rem; color: var(--muted); font-weight: 500; }
    .metric-sub { font-size: 0.75rem; margin-top: 4px; }
    .val-green  { color: var(--green); }
    .val-blue   { color: var(--blue); }
    .val-cyan   { color: var(--cyan); }
    .val-gold   { color: var(--gold); }
    .val-red    { color: var(--red); }
    .val-purple { color: var(--purple); }
    .val-white  { color: #fff; }

    /* ── Trending ── */
    .trending-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
        gap: 16px;
    }
    .trending-card {
        background: var(--card); border: 1px solid var(--border); border-radius: 12px;
        padding: 18px 20px;
        display: flex; align-items: center; gap: 16px;
        transition: transform 0.25s, border-color 0.25s;
    }
    .trending-card:hover { transform: translateX(4px); border-color: rgba(139,92,246,0.35); }
    .trend-rank { font-size: 1.6rem; font-weight: 900; color: var(--purple); min-width: 40px; }
    .trend-emoji { font-size: 2rem; }
    .trend-info { flex: 1; }
    .trend-title { font-weight: 700; font-size: 0.95rem; margin-bottom: 3px; }
    .trend-meta { font-size: 0.78rem; color: var(--muted); }
    .trend-viewers { font-size: 0.78rem; font-weight: 600; color: var(--purple); }

    /* ── AI Recommendations ── */
    .reco-strip { display: flex; gap: 12px; overflow-x: auto; padding-bottom: 8px; }
    .reco-strip::-webkit-scrollbar { height: 4px; }
    .reco-strip::-webkit-scrollbar-track { background: var(--border); border-radius: 2px; }
    .reco-strip::-webkit-scrollbar-thumb { background: var(--purple); border-radius: 2px; }
    .reco-card {
        min-width: 160px;
        background: var(--card); border: 1px solid var(--border); border-radius: 10px;
        padding: 14px; text-align: center;
        flex-shrink: 0;
        transition: transform 0.25s, border-color 0.25s;
        cursor: pointer;
    }
    .reco-card:hover { transform: translateY(-4px); border-color: rgba(139,92,246,0.4); }
    .reco-emoji { font-size: 2.2rem; margin-bottom: 8px; }
    .reco-title { font-size: 0.82rem; font-weight: 700; margin-bottom: 4px; }
    .reco-reason { font-size: 0.7rem; color: var(--purple); }

    /* ── Chaos Panel ── */
    .chaos-panel {
        background: var(--card); border-radius: 20px; padding: 32px;
        margin-bottom: 48px;
    }
    .chaos-toggle {
        display: flex; gap: 12px;
    }
    .chaos-btn {
        flex: 1; padding: 14px 24px; border-radius: 12px;
        font-size: 0.95rem; font-weight: 700; border: none; cursor: pointer;
        transition: all 0.25s;
    }
    .chaos-btn.on-btn  { background: rgba(239,68,68,0.15); color: var(--red);   border: 1px solid rgba(239,68,68,0.3); }
    .chaos-btn.off-btn { background: rgba(16,185,129,0.15); color: var(--green); border: 1px solid rgba(16,185,129,0.3); }
    .chaos-btn.on-btn:hover  { background: var(--red);   color: #fff; }
    .chaos-btn.off-btn:hover { background: var(--green); color: #fff; }
    .chaos-status-display {
        padding: 14px 20px; border-radius: 10px; margin-top: 16px;
        font-size: 0.88rem; font-weight: 600;
        transition: all 0.3s;
    }

    /* ── Status dots ── */
    .status-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; margin-right: 6px; }
    .dot-green  { background: var(--green);  box-shadow: 0 0 8px var(--green);  animation: pulse 2s infinite; }
    .dot-purple { background: var(--purple); box-shadow: 0 0 8px var(--purple); animation: pulse 2s infinite; }
    .dot-red    { background: var(--red);    box-shadow: 0 0 8px var(--red);    animation: pulse 2s infinite; }
    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }

    /* ── Chip ── */
    .chip {
        display: inline-flex; align-items: center; gap: 4px;
        padding: 3px 10px; border-radius: 20px;
        font-size: 0.72rem; font-weight: 600;
    }
    .chip-green  { background: rgba(16,185,129,0.12); color: var(--green);  border: 1px solid rgba(16,185,129,0.3); }
    .chip-purple { background: rgba(139,92,246,0.12); color: var(--purple); border: 1px solid rgba(139,92,246,0.3); }
    .chip-red    { background: rgba(239,68,68,0.12);  color: var(--red);    border: 1px solid rgba(239,68,68,0.3); }
    .chip-cyan   { background: rgba(6,182,212,0.12);  color: var(--cyan);   border: 1px solid rgba(6,182,212,0.3); }

    /* ── Player ── */
    .player-wrapper { max-width: 860px; margin: 48px auto; padding: 0 40px; position: relative; z-index: 1; }
    .player-screen {
        aspect-ratio: 16/9;
        background: linear-gradient(135deg, #050818, #130a2a, #0d1528);
        border-radius: 16px; border: 1px solid var(--border);
        display: flex; flex-direction: column; align-items: center; justify-content: center;
        gap: 16px; margin-bottom: 28px;
        position: relative; overflow: hidden;
    }
    .player-screen::before {
        content: ''; position: absolute; inset: 0;
        background: radial-gradient(ellipse at center, rgba(139,92,246,0.08) 0%, transparent 70%);
    }
    .player-icon { font-size: 4rem; }
    .player-title { font-size: 1.5rem; font-weight: 800; color: #fff; }
    .player-sub { color: var(--purple); font-size: 0.95rem; }
    .player-stats { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 16px; }
    .player-stat-card {
        background: var(--card); border: 1px solid var(--border); border-radius: 12px;
        padding: 16px 20px; display: flex; align-items: center; gap: 14px;
    }
    .stat-icon { font-size: 1.6rem; }
    .stat-text-label { font-size: 0.78rem; color: var(--muted); }
    .stat-text-value { font-size: 1rem; font-weight: 700; color: var(--green); }

    /* ── Footer ── */
    .footer {
        text-align: center; padding: 40px;
        color: var(--muted); font-size: 0.82rem;
        border-top: 1px solid var(--border);
        position: relative; z-index: 1;
    }
    .footer span { color: var(--purple); }
"""

# ─── HTML Template Builder ──────────────────────────────────────────────────
def page(title, body, extra_css=""):
    """Wraps body content in the full HTML shell with navbar and footer."""
    global chaos_mode
    chaos_indicator = (
        '<span class="nav-badge badge-danger">⚠ CHAOS ON</span>'
        if chaos_mode else
        '<span class="nav-badge badge-green">v2 · GREEN · NEW</span>'
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <meta name="description" content="StreamShield v2 — Smart Release Simulator. Green Environment. Zero-Downtime DevOps Simulator."/>
  <title>{title} | StreamShield v2 Simulator</title>
  <style>
    {SHARED_CSS}
    {extra_css}
  </style>
</head>
<body>

<!-- ── Navbar ── -->
<nav class="navbar">
  <div class="nav-logo">
    <span style="font-size:1.4rem;">🛡️</span>
    <span>StreamShield</span>
  </div>
  <div class="nav-links">
    <a href="/">Home</a>
    <a href="/watch">Smart Player</a>
    <a href="/trending">Trending</a>
    <a href="/simulator/status">Simulator</a>
    <a href="/health">Health</a>
    <a href="/metrics">Metrics</a>
  </div>
  {chaos_indicator}
</nav>

{body}

<!-- ── Footer ── -->
<footer class="footer">
  <p>🛡️ <span>StreamShield Simulator</span> — Phase 1 · v2 Green Environment</p>
  <p style="margin-top:6px;">Safe releases for high-traffic streaming platforms</p>
</footer>

<script>
  // ── Mode Switcher Logic ──────────────────────────────────────────────────
  function selectMode(mode) {{
    const unsafeCard = document.getElementById('unsafe-card');
    const smartCard  = document.getElementById('smart-card');
    const infoPanel  = document.getElementById('mode-info-panel');

    if (!unsafeCard || !smartCard || !infoPanel) return;

    // Reset both cards
    unsafeCard.classList.remove('active');
    smartCard.classList.remove('active');

    if (mode === 'unsafe') {{
      unsafeCard.classList.add('active');
      infoPanel.className = 'show';
      infoPanel.style.background = 'rgba(239,68,68,0.06)';
      infoPanel.style.border = '1px solid rgba(239,68,68,0.25)';
      infoPanel.style.borderRadius = '16px';
      infoPanel.style.padding = '24px 28px';
      infoPanel.innerHTML = `
        <div style="display:flex; align-items:center; gap:12px; margin-bottom:14px;">
          <span style="font-size:1.8rem;">⚠️</span>
          <div>
            <div style="font-weight:800; font-size:1.1rem; color:var(--red);">Unsafe Rollout — Active</div>
            <div style="font-size:0.8rem; color:var(--muted);">v2 pushed to 100% of users without validation</div>
          </div>
        </div>
        <p style="font-size:0.88rem; color:var(--muted); line-height:1.7; margin-bottom:16px;">
          ⚠️ In this mode, the new v2 release is deployed directly to ALL users.
          No QA gate, no canary traffic, no health monitoring.
          If v2 has a bug — every user is impacted immediately.
          This is what happens with <strong style="color:var(--red);">irresponsible DevOps practices</strong>.
        </p>
        <div style="display:flex; gap:10px; flex-wrap:wrap;">
          <span style="padding:4px 12px; background:rgba(239,68,68,0.12); color:var(--red); border:1px solid rgba(239,68,68,0.3); border-radius:8px; font-size:0.78rem; font-weight:700;">💀 High Risk</span>
          <span style="padding:4px 12px; background:rgba(239,68,68,0.12); color:var(--red); border:1px solid rgba(239,68,68,0.3); border-radius:8px; font-size:0.78rem; font-weight:700;">⚠️ 500 Errors Possible</span>
          <span style="padding:4px 12px; background:rgba(239,68,68,0.12); color:var(--red); border:1px solid rgba(239,68,68,0.3); border-radius:8px; font-size:0.78rem; font-weight:700;">📵 No Rollback</span>
        </div>
      `;
    }} else {{
      smartCard.classList.add('active');
      infoPanel.className = 'show';
      infoPanel.style.background = 'rgba(16,185,129,0.06)';
      infoPanel.style.border = '1px solid rgba(16,185,129,0.25)';
      infoPanel.style.borderRadius = '16px';
      infoPanel.style.padding = '24px 28px';
      infoPanel.innerHTML = `
        <div style="display:flex; align-items:center; gap:12px; margin-bottom:14px;">
          <span style="font-size:1.8rem;">✅</span>
          <div>
            <div style="font-weight:800; font-size:1.1rem; color:var(--green);">Smart Rollout — Active</div>
            <div style="font-size:0.8rem; color:var(--muted);">Safe canary rollout with full health monitoring</div>
          </div>
        </div>
        <p style="font-size:0.88rem; color:var(--muted); line-height:1.7; margin-bottom:16px;">
          ✅ In this mode, v2 is first verified by <strong style="color:var(--green);">Internal QA</strong>.
          Only 10% of real users receive v2 via <strong style="color:var(--green);">canary traffic split</strong>.
          Health score is monitored in real-time. If issues are detected,
          <strong style="color:var(--green);">automatic rollback</strong> brings all traffic back to stable v1.
        </p>
        <div style="display:flex; gap:10px; flex-wrap:wrap;">
          <span style="padding:4px 12px; background:rgba(16,185,129,0.12); color:var(--green); border:1px solid rgba(16,185,129,0.3); border-radius:8px; font-size:0.78rem; font-weight:700;">🛡️ Low Risk</span>
          <span style="padding:4px 12px; background:rgba(16,185,129,0.12); color:var(--green); border:1px solid rgba(16,185,129,0.3); border-radius:8px; font-size:0.78rem; font-weight:700;">✅ QA Gated</span>
          <span style="padding:4px 12px; background:rgba(16,185,129,0.12); color:var(--green); border:1px solid rgba(16,185,129,0.3); border-radius:8px; font-size:0.78rem; font-weight:700;">🔄 Auto Rollback</span>
        </div>
      `;
    }}
  }}

  // ── Chaos Mode Toggle ─────────────────────────────────────────────────────
  async function setChaos(enable) {{
    const route = enable ? '/chaos/on' : '/chaos/off';
    try {{
      const res = await fetch(route);
      const data = await res.json();
      const statusEl = document.getElementById('chaos-status');
      if (statusEl) {{
        if (data.chaos_mode) {{
          statusEl.style.background = 'rgba(239,68,68,0.1)';
          statusEl.style.border = '1px solid rgba(239,68,68,0.3)';
          statusEl.style.color = 'var(--red)';
          statusEl.innerHTML = '💀 Chaos Mode ACTIVE — /watch will randomly fail with 500 errors and high latency!';
        }} else {{
          statusEl.style.background = 'rgba(16,185,129,0.1)';
          statusEl.style.border = '1px solid rgba(16,185,129,0.3)';
          statusEl.style.color = 'var(--green)';
          statusEl.innerHTML = '✅ Chaos Mode DISABLED — /watch is operating normally.';
        }}
      }}
    }} catch(e) {{
      console.error('Chaos toggle error:', e);
    }}
  }}
</script>
</body>
</html>"""


# =============================================================================
# ROUTE: / — Homepage
# =============================================================================
@app.route("/")
def homepage():
    """
    v2 homepage: shows the mode switcher, AI recommendations,
    movie grid, and chaos control panel.
    """
    start = time.time()

    # ── Movie Cards HTML ─────────────────────────────────────────────────────
    movie_cards_html = ""
    for m in MOVIES:
        new_badge = '<div class="new-badge">NEW</div>' if m.get("new") else ""
        movie_cards_html += f"""
        <div class="movie-card">
          <div class="movie-thumb movie-thumb-v2">
            {new_badge}
            <span>{m['emoji']}</span>
          </div>
          <div class="movie-info">
            <div class="movie-title">{m['title']}</div>
            <div class="movie-meta">
              <span class="movie-genre">{m['genre']}</span>
              <span class="movie-rating">★ {m['rating']}</span>
              <span class="movie-year">{m['year']}</span>
            </div>
            <a href="/watch" class="play-btn">▶ Smart Play</a>
          </div>
        </div>"""

    # ── AI Reco strip HTML ───────────────────────────────────────────────────
    recos = [
        ("🚀", "DevOps Secrets", "Based on DevOps Documentary"),
        ("🤖", "AI Takeover",    "Trending near you"),
        ("🔐", "Cyber Heist 2",  "Because you watched Cyber Heist"),
        ("🌌", "Space Wars II",  "New release you'll love"),
        ("🏆", "Sports Legends", "Trending in your area"),
        ("🎬", "Code Breakers",  "Recommended for you"),
    ]
    reco_html = ""
    for emoji, title, reason in recos:
        reco_html += f"""
        <div class="reco-card">
          <div class="reco-emoji">{emoji}</div>
          <div class="reco-title">{title}</div>
          <div class="reco-reason">{reason}</div>
        </div>"""

    chaos_status_color = "rgba(239,68,68,0.1)" if chaos_mode else "rgba(16,185,129,0.1)"
    chaos_status_border = "rgba(239,68,68,0.3)" if chaos_mode else "rgba(16,185,129,0.3)"
    chaos_status_text_color = "var(--red)" if chaos_mode else "var(--green)"
    chaos_status_msg = (
        "💀 Chaos Mode ACTIVE — /watch will randomly fail with 500 errors and high latency!"
        if chaos_mode else
        "✅ Chaos Mode DISABLED — /watch is operating normally."
    )

    body = f"""
    <!-- ── Hero ── -->
    <div class="hero">
      <div class="hero-eyebrow">🚀 DEVOPS SIMULATOR · v2 GREEN ENVIRONMENT</div>
      <h1>StreamShield v2<br>Smart Release Simulator</h1>
      <p>New streaming experience with smart player, trending engine, and DevOps release simulation.<br>
         Compare <strong style="color:var(--red);">Unsafe Rollout</strong> vs
         <strong style="color:var(--green);">Smart Rollout</strong> — side by side.</p>
      <div style="display:flex; justify-content:center; gap:12px; flex-wrap:wrap; margin-top:8px;">
        <span class="chip chip-green">🟢 GREEN ENVIRONMENT — NEW RELEASE</span>
        <span class="chip chip-purple">🧪 RELEASE SIMULATOR ACTIVE</span>
        {'<span class="chip chip-red">⚠️ CHAOS MODE ON</span>' if chaos_mode else '<span class="chip chip-cyan">✅ CHAOS MODE OFF</span>'}
      </div>
    </div>

    <div class="section" style="padding-top:0;">

      <!-- ── Mode Switcher ── -->
      <div class="section-title"><span class="dot"></span> Release Mode Simulator</div>
      <div class="section-sub">Click a mode to understand the DevOps release strategy and its impact</div>

      <div class="mode-switcher">

        <!-- Unsafe Mode Card -->
        <div class="mode-card unsafe" id="unsafe-card" onclick="selectMode('unsafe')">
          <div class="mode-icon">⚠️</div>
          <div class="mode-title" style="color:var(--red);">Unsafe Rollout Mode</div>
          <div class="mode-desc">
            Simulates direct release of v2 to ALL users without any safety checks.
            No internal QA, no canary testing, no rollback strategy.
          </div>
          <div class="mode-metrics">
            <div class="mode-metric-row">
              <span class="mode-metric-key">Traffic to v2</span>
              <span class="mode-badge mb-red">100% — All Users</span>
            </div>
            <div class="mode-metric-row">
              <span class="mode-metric-key">Internal QA</span>
              <span class="mode-badge mb-red">Skipped ✗</span>
            </div>
            <div class="mode-metric-row">
              <span class="mode-metric-key">Canary Rollout</span>
              <span class="mode-badge mb-red">Disabled ✗</span>
            </div>
            <div class="mode-metric-row">
              <span class="mode-metric-key">Health Score</span>
              <span class="mode-badge mb-yellow">Low (on failure)</span>
            </div>
            <div class="mode-metric-row">
              <span class="mode-metric-key">Rollback</span>
              <span class="mode-badge mb-red">Not Available ✗</span>
            </div>
          </div>
          <button class="mode-select-btn" onclick="event.stopPropagation(); selectMode('unsafe')">⚠️ Simulate Unsafe Rollout</button>
        </div>

        <!-- Smart Mode Card -->
        <div class="mode-card smart" id="smart-card" onclick="selectMode('smart')">
          <div class="mode-icon">✅</div>
          <div class="mode-title" style="color:var(--green);">Smart Rollout Mode</div>
          <div class="mode-desc">
            Simulates safe canary rollout using internal QA, gradual traffic shift,
            real-time health scoring, and automatic rollback on failure.
          </div>
          <div class="mode-metrics">
            <div class="mode-metric-row">
              <span class="mode-metric-key">Traffic to v2</span>
              <span class="mode-badge mb-green">10% — Canary Users</span>
            </div>
            <div class="mode-metric-row">
              <span class="mode-metric-key">Internal QA</span>
              <span class="mode-badge mb-green">Enabled ✓</span>
            </div>
            <div class="mode-metric-row">
              <span class="mode-metric-key">Canary Rollout</span>
              <span class="mode-badge mb-green">Enabled ✓</span>
            </div>
            <div class="mode-metric-row">
              <span class="mode-metric-key">Health Score</span>
              <span class="mode-badge mb-green">Active ✓</span>
            </div>
            <div class="mode-metric-row">
              <span class="mode-metric-key">Rollback</span>
              <span class="mode-badge mb-green">Ready ✓</span>
            </div>
          </div>
          <button class="mode-select-btn" onclick="event.stopPropagation(); selectMode('smart')">✅ Simulate Smart Rollout</button>
        </div>
      </div>

      <!-- Mode Info Panel (populated by JS) -->
      <div id="mode-info-panel"></div>
      <!-- ───────────────────────────────────────────── -->
      <!-- RELEASE CONTROL CENTER (NEW ADDITION) -->
      <!-- ───────────────────────────────────────────── -->

      <div class="section-title" style="margin-top:48px;">
        <span class="dot"></span>
        Release Control Center
      </div>

      <div class="section-sub">
        Real-time deployment visibility dashboard
      </div>

      <div style="
      display:grid;
      grid-template-columns:repeat(auto-fit,minmax(240px,1fr));
      gap:20px;
      margin-bottom:40px;
      ">

        <div class="glass-card" style="padding:24px;text-align:center;">
            <h3 style="color:var(--green);">🏥 Deployment Health</h3>
            <h1>98%</h1>
            <p style="color:var(--muted);">Healthy Release Candidate</p>
        </div>

        <div class="glass-card" style="padding:24px;text-align:center;">
            <h3 style="color:var(--cyan);">🎯 Canary Traffic</h3>
            <h1>10%</h1>
            <p style="color:var(--muted);">Traffic routed to v2</p>
        </div>

        <div class="glass-card" style="padding:24px;text-align:center;">
            <h3 style="color:var(--purple);">👨‍💻 Internal QA</h3>
            <h1>100%</h1>
            <p style="color:var(--muted);">QA Team Validation</p>
        </div>

        <div class="glass-card" style="padding:24px;text-align:center;">
            <h3 style="color:var(--gold);">🔄 Auto Rollback</h3>
            <h1>ARMED</h1>
            <p style="color:var(--muted);">Trigger at >5% Error Rate</p>
        </div>

      </div>

      <div class="section-title">
        <span class="dot"></span>
        Release Timeline
      </div>

      <div class="glass-card" style="padding:24px;margin-bottom:40px;">
        <p>✅ Internal QA Rollout Complete</p>
        <br>
        <p>✅ Canary Deployment Active (10%)</p>
        <br>
        <p>⏳ Production Rollout Pending (50%)</p>
        <br>
        <p>🚀 Full Production Deployment (100%)</p>
      </div>

      <!-- ───────────────────────────────────────────── -->
      <!-- END RELEASE CONTROL CENTER -->
      <!-- ───────────────────────────────────────────── -->

      <!-- ── Chaos Mode Control Panel ── -->
      <div class="section-title" style="margin-top:48px;"><span class="dot"></span> Bad Release Simulator (Chaos Mode)</div>
      <div class="section-sub">Toggle chaos mode to simulate what happens during a buggy v2 release</div>

      <div class="chaos-panel" style="border: 1px solid {'rgba(239,68,68,0.3)' if chaos_mode else 'var(--border)'};">
        <div style="display:flex; align-items:center; gap:12px; margin-bottom:20px;">
          <span style="font-size:1.6rem;">💥</span>
          <div>
            <div style="font-weight:800; font-size:1.05rem;">Chaos Mode Control</div>
            <div style="font-size:0.82rem; color:var(--muted);">
              Activating chaos simulates a buggy v2 release — random 500s, high latency, playback failures
            </div>
          </div>
        </div>
        <div class="chaos-toggle">
          <button class="chaos-btn on-btn"  id="chaos-on-btn"  onclick="setChaos(true)">💀 Enable Chaos Mode</button>
          <button class="chaos-btn off-btn" id="chaos-off-btn" onclick="setChaos(false)">✅ Disable Chaos Mode</button>
        </div>
        <div class="chaos-status-display" id="chaos-status"
             style="background:{chaos_status_color}; border:1px solid {chaos_status_border}; color:{chaos_status_text_color};">
          {chaos_status_msg}
        </div>
      </div>

      <!-- ── AI Recommendations ── -->
      <div class="section-title"><span class="dot"></span> Recommended For You</div>
      <div class="section-sub" style="margin-bottom:16px;">
        Because you watched <strong style="color:var(--purple);">DevOps Documentary</strong> · Trending near you
      </div>
      <div class="reco-strip" style="margin-bottom:48px;">
        {reco_html}
      </div>

      <!-- ── Movie Grid ── -->
      <div class="section-title"><span class="dot"></span> Featured Titles</div>
      <div class="section-sub">Explore the new streaming catalogue on v2</div>
      <div class="movies-grid" style="margin-bottom:48px;">
        {movie_cards_html}
      </div>

    </div>
    """

    elapsed = time.time() - start
    request_latency.labels(version="v2", endpoint="/").observe(elapsed)
    http_requests_total.labels(version="v2", endpoint="/", status="200").inc()
    return page("Home", body)


# =============================================================================
# ROUTE: /health — Health Check (JSON)
# =============================================================================
@app.route("/health")
def health():
    """Returns health status as JSON. Chaos mode is reflected in response."""
    global chaos_mode
    status = "degraded" if chaos_mode else "healthy"
    http_requests_total.labels(version="v2", endpoint="/health", status="200").inc()
    return jsonify({
        "status": status,
        "version": "v2",
        "environment": "green",
        "chaos_mode": chaos_mode,
        "message": (
            "v2 is in chaos mode — bad release simulation active"
            if chaos_mode else
            "v2 new release is healthy"
        )
    })


# =============================================================================
# ROUTE: /movies — Movie List (JSON)
# =============================================================================
@app.route("/movies")
def movies():
    """Returns JSON list of v2 movies."""
    http_requests_total.labels(version="v2", endpoint="/movies", status="200").inc()
    return jsonify({
        "version": "v2",
        "environment": "green",
        "total": len(MOVIES),
        "movies": MOVIES
    })


# =============================================================================
# ROUTE: /watch — Smart Player (with Chaos Mode support)
# =============================================================================
@app.route("/watch")
def watch():
    """
    Smart video player for v2.
    When chaos_mode is ON:
      - 40% chance of HTTP 500 error
      - 30% chance of high latency (time.sleep)
      - Increments playback_failures_total metric
    When chaos_mode is OFF: behaves normally.
    """
    global chaos_mode
    start = time.time()

    # ── Chaos mode: simulate bad release ──────────────────────────────────────
    if chaos_mode:
        roll = random.random()

        if roll < 0.40:
            # Simulate HTTP 500 — server crash
            playback_failures_total.labels(version="v2").inc()
            http_requests_total.labels(version="v2", endpoint="/watch", status="500").inc()
            elapsed = time.time() - start
            request_latency.labels(version="v2", endpoint="/watch").observe(elapsed)
            error_body = """
            <div style="max-width:700px; margin:80px auto; padding:0 40px; text-align:center; position:relative; z-index:1;">
              <div style="font-size:5rem; margin-bottom:20px;">💀</div>
              <h1 style="font-size:2rem; font-weight:900; color:var(--red); margin-bottom:12px;">500 — Internal Server Error</h1>
              <p style="color:var(--muted); font-size:1rem; line-height:1.7; margin-bottom:24px;">
                The v2 player engine has crashed. This is what happens during an
                <strong style="color:var(--red);">Unsafe Rollout</strong> — all users see this error.
                <br><br>
                In <strong style="color:var(--green);">Smart Rollout</strong>, only 10% of canary users would be affected,
                and automatic rollback would restore v1 immediately.
              </p>
              <div style="padding:16px 20px; background:rgba(239,68,68,0.08); border:1px solid rgba(239,68,68,0.25); border-radius:12px; margin-bottom:20px; text-align:left;">
                <div style="font-size:0.8rem; color:var(--red); font-weight:700; margin-bottom:8px;">⚠️ DEVOPS INSIGHT</div>
                <div style="font-size:0.85rem; color:var(--muted); line-height:1.6;">
                  Chaos Mode is currently <strong style="color:var(--red);">ACTIVE</strong>. This simulates a buggy v2 release.
                  Go to the <a href="/" style="color:var(--purple);">homepage</a> and disable chaos mode, or use the
                  <a href="/chaos/off" style="color:var(--purple);">/chaos/off</a> endpoint to restore normal operation.
                </div>
              </div>
              <a href="/" style="color:var(--purple); text-decoration:none; font-size:0.9rem;">← Back to Simulator</a>
            </div>
            """
            return page("500 Error — Chaos", error_body), 500

        elif roll < 0.70:
            # Simulate high latency
            delay = random.uniform(2.0, 5.0)
            time.sleep(delay)
            playback_failures_total.labels(version="v2").inc()

    # ── Normal / delayed but successful response ───────────────────────────────
    is_degraded = chaos_mode
    player_status = "⚠️ Degraded (Chaos Active)" if is_degraded else "✅ Smooth"
    quality = "Buffering..." if is_degraded else "4K Ultra HD"
    buffer_status = "High Buffering" if is_degraded else "Optimized"
    status_color = "var(--red)" if is_degraded else "var(--green)"

    body = f"""
    <div class="player-wrapper">
      <div style="margin-bottom:20px;">
        <a href="/" style="color:var(--purple); text-decoration:none; font-size:0.9rem;">← Back to Simulator</a>
      </div>

      <div style="margin-bottom:20px;">
        <h2 style="font-size:1.5rem; font-weight:800; margin-bottom:8px;">
          Smart Player <span style="color:var(--purple);">v2</span>
          {'<span style="color:var(--red); font-size:0.9rem;">&nbsp;— Chaos Mode Active</span>' if is_degraded else ''}
        </h2>
        <div style="display:flex; gap:10px; flex-wrap:wrap;">
          <span class="chip chip-green">🟢 GREEN ENVIRONMENT</span>
          {'<span class="chip chip-red">⚠️ DEGRADED PLAYBACK</span>' if is_degraded else '<span class="chip chip-purple">✅ SMART PLAYER ACTIVE</span>'}
        </div>
      </div>

      <!-- Player Screen -->
      <div class="player-screen">
        <div class="player-icon">{'⚠️' if is_degraded else '▶️'}</div>
        <div class="player-title">Smart Player v2</div>
        <div class="player-sub" style="color:{status_color};">{player_status}</div>
        <div style="position:absolute; bottom:20px; left:0; right:0; padding:0 28px;">
          <div style="height:4px; background:var(--border); border-radius:2px; overflow:hidden;">
            <div style="width:{'8%' if is_degraded else '52%'}; height:100%;
                 background:linear-gradient(90deg, {'var(--red)' if is_degraded else 'var(--purple)'}, var(--cyan));
                 border-radius:2px; transition: width 0.5s;"></div>
          </div>
          <div style="display:flex; justify-content:space-between; margin-top:6px; font-size:0.75rem; color:var(--muted);">
            <span>{'0:02 (buffering...)' if is_degraded else '1:12'}</span><span>2:10:00</span>
          </div>
        </div>
      </div>

      <!-- Stats -->
      <div class="player-stats">
        <div class="player-stat-card">
          <span class="stat-icon">🎬</span>
          <div>
            <div class="stat-text-label">Playback Status</div>
            <div class="stat-text-value" style="color:{status_color};">{player_status}</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">🎯</span>
          <div>
            <div class="stat-text-label">Video Quality</div>
            <div class="stat-text-value" style="color:{status_color};">{quality}</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">⚡</span>
          <div>
            <div class="stat-text-label">Buffer Optimization</div>
            <div class="stat-text-value" style="color:{status_color};">{buffer_status}</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">🧠</span>
          <div>
            <div class="stat-text-label">Player Engine</div>
            <div class="stat-text-value" style="color:var(--purple);">New Player Engine v2</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">📺</span>
          <div>
            <div class="stat-text-label">4K Adaptive Streaming</div>
            <div class="stat-text-value" style="color:var(--purple);">Enabled</div>
          </div>
        </div>
        <div class="player-stat-card">
          <span class="stat-icon">🔖</span>
          <div>
            <div class="stat-text-label">Continue Watching</div>
            <div class="stat-text-value" style="color:var(--purple);">Personalized ✓</div>
          </div>
        </div>
      </div>

      <div style="margin-top:24px; padding:16px 20px;
           background:{'rgba(239,68,68,0.06)' if is_degraded else 'rgba(139,92,246,0.06)'};
           border:1px solid {'rgba(239,68,68,0.2)' if is_degraded else 'rgba(139,92,246,0.2)'};
           border-radius:12px;">
        <div style="font-weight:700; color:{status_color}; margin-bottom:6px;">
          {'⚠️ Chaos Mode Active' if is_degraded else '✨ Smart Player Features'}
        </div>
        <div style="font-size:0.85rem; color:var(--muted); line-height:1.6;">
          {'The bad release simulation is active. This is why chaos mode must be caught early via health checks and canary traffic — before reaching 100% of users. <a href="/chaos/off" style="color:var(--purple);">Disable chaos</a> to restore playback.' if is_degraded else 'Personalized Playback Experience · 4K Adaptive Streaming · Smart Buffer Optimization · AI-powered Continue Watching.'}
        </div>
      </div>
    </div>
    """

    elapsed = time.time() - start
    request_latency.labels(version="v2", endpoint="/watch").observe(elapsed)
    status_code = "200"
    http_requests_total.labels(version="v2", endpoint="/watch", status=status_code).inc()
    return page("Smart Player", body)


# =============================================================================
# ROUTE: /trending — Trending Page
# =============================================================================
@app.route("/trending")
def trending():
    """Trending Now page with top shows ranked by live viewers."""
    start = time.time()

    trend_cards_html = ""
    for t in TRENDING:
        trend_cards_html += f"""
        <div class="trending-card">
          <div class="trend-rank">#{t['rank']}</div>
          <div class="trend-emoji">{t['emoji']}</div>
          <div class="trend-info">
            <div class="trend-title">{t['title']}</div>
            <div class="trend-meta">{t['genre']}</div>
          </div>
          <div style="text-align:right;">
            <div class="trend-viewers">{t['viewers']}</div>
            <div style="font-size:1rem;">{t['trend']}</div>
          </div>
        </div>"""

    body = f"""
    <div class="section">
      <div style="margin-bottom:32px;">
        <a href="/" style="color:var(--purple); text-decoration:none; font-size:0.9rem;">← Back to Home</a>
      </div>
      <div class="section-title"><span class="dot"></span> Trending Now</div>
      <div class="section-sub">Live viewer counts updated in real-time across the streaming platform</div>

      <div class="trending-grid">
        {trend_cards_html}
      </div>

      <div style="margin-top:40px; padding:24px; background:var(--card); border:1px solid var(--border); border-radius:16px;">
        <div style="font-weight:700; color:var(--purple); margin-bottom:8px;">🚀 v2 Trending Engine</div>
        <div style="font-size:0.88rem; color:var(--muted); line-height:1.6;">
          The new v2 trending engine uses real-time viewer analytics to surface
          the most-watched content. This feature is part of the v2 release being
          tested via <strong style="color:var(--green);">Smart Canary Rollout</strong> —
          ensuring only 10% of users get this new feature first.
        </div>
      </div>
    </div>
    """

    elapsed = time.time() - start
    request_latency.labels(version="v2", endpoint="/trending").observe(elapsed)
    http_requests_total.labels(version="v2", endpoint="/trending", status="200").inc()
    return page("Trending", body)


# =============================================================================
# ROUTE: /chaos/on — Enable Chaos Mode
# =============================================================================
@app.route("/chaos/on")
def chaos_on():
    """Enables chaos mode — simulates a bad v2 release."""
    global chaos_mode
    chaos_mode = True
    chaos_mode_gauge.set(1.0)  # Update Prometheus gauge
    http_requests_total.labels(version="v2", endpoint="/chaos/on", status="200").inc()
    return jsonify({
        "chaos_mode": True,
        "message": "Bad release simulation enabled",
        "effect": "GET /watch will randomly return 500 errors and high latency",
        "devops_note": "In Smart Rollout, this would trigger automatic rollback to v1"
    })


# =============================================================================
# ROUTE: /chaos/off — Disable Chaos Mode
# =============================================================================
@app.route("/chaos/off")
def chaos_off():
    """Disables chaos mode — restores normal v2 operation."""
    global chaos_mode
    chaos_mode = False
    chaos_mode_gauge.set(0.0)  # Update Prometheus gauge
    http_requests_total.labels(version="v2", endpoint="/chaos/off", status="200").inc()
    return jsonify({
        "chaos_mode": False,
        "message": "Bad release simulation disabled",
        "effect": "GET /watch is now operating normally",
        "devops_note": "System restored — rollback simulation complete"
    })


# =============================================================================
# ROUTE: /simulator/status — Full Simulator Status (JSON)
# =============================================================================
@app.route("/simulator/status")
def simulator_status():
    """Returns complete simulator state as JSON — used by monitoring dashboards."""
    global chaos_mode
    http_requests_total.labels(version="v2", endpoint="/simulator/status", status="200").inc()
    return jsonify({
        "version": "v2",
        "environment": "green",
        "unsafe_rollout": {
            "traffic_to_v2": "100%",
            "internal_qa": "skipped",
            "canary": "disabled",
            "rollback": "not_available",
            "risk": "high"
        },
        "smart_rollout": {
            "traffic_to_v2": "10%",
            "internal_qa": "enabled",
            "canary": "enabled",
            "health_score": "active",
            "rollback": "ready",
            "risk": "low"
        },
        "chaos_mode": chaos_mode,
        "chaos_effect": (
            "Random 500 errors and high latency on /watch" if chaos_mode
            else "No chaos — normal operation"
        )
    })


# =============================================================================
# ROUTE: /release-mode/unsafe — Unsafe Rollout Info (JSON)
# =============================================================================
@app.route("/release-mode/unsafe")
def release_mode_unsafe():
    """Returns JSON describing the unsafe rollout scenario."""
    http_requests_total.labels(version="v2", endpoint="/release-mode/unsafe", status="200").inc()
    return jsonify({
        "mode": "unsafe_rollout",
        "description": "Direct release of v2 to 100% of users without testing",
        "traffic_to_v2": "100%",
        "internal_qa": "skipped",
        "canary_enabled": False,
        "health_monitoring": "none",
        "rollback": "not_available",
        "risk": "critical",
        "impact": "All users experience outage if v2 has bugs"
    })

# ROUTE: /release-mode/smart — Smart Rollout Info (JSON)
@app.route("/release-mode/smart")
def release_mode_smart():
    """Returns JSON describing the smart rollout scenario."""
    http_requests_total.labels(version="v2", endpoint="/release-mode/smart", status="200").inc()
    return jsonify({
        "mode": "smart_rollout",
        "description": "Gradual canary release with QA gate, health monitoring, and auto rollback",
        "traffic_to_v2": "10%",
        "internal_qa": "enabled",
        "canary_enabled": True,
        "health_monitoring": "active",
        "rollback": "ready",
        "risk": "low",
        "impact": "90% of users stay safely on v1 while v2 is validated"
    })

# ROUTE: /metrics — Prometheus Metrics

@app.route("/metrics")
def metrics():
    """
    Exposes Prometheus-compatible metrics.
    Scraped by Prometheus in Phase 2 (Kubernetes setup).
    Includes chaos_mode gauge for alerting.
    """
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


# =============================================================================
# Main Entry Point
# =============================================================================
if __name__ == "__main__":
    # host="0.0.0.0" makes Flask accessible outside the container
    print("🛡️  StreamShield v2 — Green Environment (Smart Release Simulator)")
    print("🌐  Running on http://0.0.0.0:5000")
    print("📊  Metrics at http://0.0.0.0:5000/metrics")
    print("💥  Chaos mode: OFF (use /chaos/on to enable)")
    app.run(host="0.0.0.0", port=5000, debug=False)
