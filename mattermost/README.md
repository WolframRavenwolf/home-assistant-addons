# Mattermost

Mattermost Team Edition packaged as a Home Assistant add-on for LAN access by users, bots, and agents.

This add-on installs Mattermost and PostgreSQL in one container. It is intended for internal use first: your browser, desktop/mobile Mattermost clients, and trusted bots or agents can reach it over the LAN. Cloudflare Tunnel or Tailscale can be added later in front of the same direct URL.

See [DOCS.md](DOCS.md) for installation, configuration, storage, and security details.

## Highlights

- Mattermost Team Edition 11.7.2 ESR.
- Built-in PostgreSQL with persistent storage under `/config/postgres`.
- Persistent Mattermost config, files, plugins, logs, and TLS certs under `/config/mattermost`.
- Home Assistant sidebar landing page with health status.
- Direct LAN HTTP on port `8065`.
- Direct LAN HTTPS on port `8465` with an add-on generated CA certificate.
- Bot-friendly defaults: bot account creation, personal access tokens, slash commands, incoming webhooks, and outgoing webhooks are enabled.
- Optional nginx Basic Auth for direct ports.
- Optional CORS allowlist through `MM_SERVICESETTINGS_ALLOWCORSFROM` for browser-based integrations that call the Mattermost API from another origin.

## Access

Open `http://homeassistant.local:8065/` or the URL configured in `site_url`. Replace `homeassistant.local` with your Home Assistant hostname or IP if needed.

## Security

Keep this LAN-only unless a separate remote-access design is explicitly approved. Mattermost accounts and API tokens protect the application itself; optional nginx Basic Auth can add another gate for direct HTTP/HTTPS ports.
