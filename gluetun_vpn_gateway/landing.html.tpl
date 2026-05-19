<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Gluetun VPN Gateway</title>
<style>
  *{box-sizing:border-box}
  html,body{margin:0;padding:0;min-height:100%;background:#0f172a;color:#e5e7eb;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
  body{display:flex;align-items:center;justify-content:center;padding:24px}
  main{width:min(860px,100%)}
  h1{margin:0 0 8px;font-size:28px;line-height:1.15}
  h2{margin:28px 0 10px;font-size:18px;color:#f9fafb}
  p,li{color:#cbd5e1;line-height:1.5}
  code,pre{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
  pre{background:#111827;border:1px solid #334155;border-radius:8px;padding:14px;overflow:auto;color:#e5e7eb}
  dl{display:grid;grid-template-columns:max-content 1fr;gap:8px 14px;margin:22px 0;color:#d1d5db;font-size:14px}
  dt{color:#94a3b8} dd{margin:0;overflow-wrap:anywhere}
  .card{border:1px solid #334155;border-radius:12px;padding:18px;background:#111827cc;box-shadow:0 20px 60px #0005}
  .badge{display:inline-block;padding:3px 8px;border-radius:999px;background:#1d4ed8;color:#dbeafe;font-size:12px;font-weight:700;margin-bottom:12px}
  .warn{border-left:4px solid #f59e0b;padding-left:12px;color:#fde68a}
</style>
</head>
<body>
<main class="card">
  <span class="badge">LAN-only VPN gateway / proxy</span>
  <h1>Gluetun VPN Gateway</h1>
  <p>This Home Assistant add-on runs Gluetun and exposes selected proxy ports so individual LAN clients or apps can route through a configurable VPN tunnel without changing the whole network gateway.</p>

  <dl>
    <dt>Provider</dt><dd><code>%%VPN_SERVICE_PROVIDER%%</code></dd>
    <dt>VPN type</dt><dd><code>%%VPN_TYPE%%</code></dd>
    <dt>Country filter</dt><dd><code>%%SERVER_COUNTRIES%%</code></dd>
    <dt>City filter</dt><dd><code>%%SERVER_CITIES%%</code></dd>
    <dt>HTTP CONNECT proxy</dt><dd><code>http://%%HOST_HINT%%:%%HTTP_PROXY_PORT%%</code></dd>
    <dt>Shadowsocks</dt><dd><code>%%HOST_HINT%%:%%SHADOWSOCKS_PORT%%</code> if enabled</dd>
  </dl>

  <h2>Codex Desktop / CLI proxy example</h2>
  <pre>mkdir -p ~/.codex
cat &gt; ~/.codex/.env &lt;&lt;'EOF'
http_proxy=http://%%HOST_HINT%%:%%HTTP_PROXY_PORT%%
https_proxy=http://%%HOST_HINT%%:%%HTTP_PROXY_PORT%%
HTTP_PROXY=http://%%HOST_HINT%%:%%HTTP_PROXY_PORT%%
HTTPS_PROXY=http://%%HOST_HINT%%:%%HTTP_PROXY_PORT%%
no_proxy=localhost,127.0.0.1,::1
NO_PROXY=localhost,127.0.0.1,::1
EOF</pre>

  <p class="warn">Do not expose this add-on to the public internet. Keep the proxy LAN-only or behind a trusted private network. If the VPN tunnel is down, Gluetun's firewall/kill-switch should block proxy egress rather than leaking through the regular WAN.</p>
</main>
</body>
</html>
