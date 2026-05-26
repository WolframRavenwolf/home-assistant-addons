<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mattermost</title>
<style>
  *{box-sizing:border-box}
  html,body{margin:0;padding:0;min-height:100%;background:#111827;color:#e5e7eb;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
  body{display:flex;align-items:center;justify-content:center;padding:24px}
  main{width:min(760px,100%)}
  h1{margin:0 0 8px;font-size:28px;line-height:1.15}
  p{margin:0;color:#9ca3af;line-height:1.5}
  .status{display:flex;gap:10px;align-items:center;margin:22px 0;color:#d1d5db}
  .dot{width:10px;height:10px;border-radius:999px;background:#f59e0b;box-shadow:0 0 16px #f59e0b}
  .dot.ok{background:#22c55e;box-shadow:0 0 16px #22c55e}
  .dot.bad{background:#ef4444;box-shadow:0 0 16px #ef4444}
  .actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:20px}
  a.button{display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:0 14px;border-radius:6px;text-decoration:none;color:#07111f;background:#36c5f0;font-weight:650}
  a.button.secondary{color:#e5e7eb;background:#243244}
  dl{display:grid;grid-template-columns:max-content 1fr;gap:8px 14px;margin:24px 0 0;color:#d1d5db;font-size:14px}
  dt{color:#9ca3af}
  dd{margin:0;overflow-wrap:anywhere}
  code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
  @media(max-width:560px){body{padding:18px}h1{font-size:24px}dl{grid-template-columns:1fr}.actions a.button{width:100%}}
</style>
</head>
<body>
<main>
  <h1>Mattermost</h1>
  <p>Local Home Assistant add-on for Mattermost Team Edition. Use the direct LAN URL for the web app, desktop client, mobile client, and trusted bots or agents.</p>

  <div class="status">
    <span class="dot" id="dot"></span>
    <span id="status">Checking Mattermost...</span>
  </div>

  <div class="actions">
    <a class="button" href="%%SITE_URL%%" target="_blank" rel="noreferrer">Open Mattermost</a>
    <a class="button secondary" href="https://%%SITE_HOST%%:%%HTTPS_PORT%%/" target="_blank" rel="noreferrer">Open HTTPS</a>
    <a class="button secondary" href="https://%%SITE_HOST%%:%%HTTPS_PORT%%/cert/ca.crt" target="_blank" rel="noreferrer">Download CA</a>
    <a class="button secondary" href="/config/app/%%ADDON_SLUG%%/info" target="_top">App Info</a>
  </div>

  <dl>
    <dt>Version</dt><dd><code>%%MATTERMOST_VERSION%%</code></dd>
    <dt>HTTP</dt><dd><code>%%SITE_URL%%</code></dd>
    <dt>HTTPS</dt><dd><code>https://%%SITE_HOST%%:%%HTTPS_PORT%%/</code></dd>
    <dt>API ping</dt><dd><code>%%SITE_URL%%/api/v4/system/ping</code></dd>
  </dl>
</main>

<script>
(function() {
  var dot = document.getElementById('dot');
  var status = document.getElementById('status');
  fetch('./health', {cache:'no-store'}).then(function(r) {
    if (r.ok) {
      dot.className = 'dot ok';
      status.textContent = 'Mattermost is running';
    } else {
      dot.className = 'dot bad';
      status.textContent = 'Mattermost answered with HTTP ' + r.status;
    }
  }).catch(function() {
    dot.className = 'dot bad';
    status.textContent = 'Mattermost is not reachable yet';
  });
})();
</script>
</body>
</html>
