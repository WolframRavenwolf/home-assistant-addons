# Mattermost Home Assistant Add-on

> Mattermost Team Edition packaged as a local Home Assistant add-on for LAN access by users and agents.

This add-on installs Mattermost and PostgreSQL in one Home Assistant add-on container. It is intended for internal use first: your browser, desktop/mobile Mattermost clients, and trusted bots or agents can reach it over the LAN. Cloudflare Tunnel or Tailscale can be added later in front of the same direct URL.

## Features

- Mattermost Team Edition 11.6.1
- Built-in PostgreSQL with persistent storage under `/config/postgres`
- Persistent Mattermost config, files, plugins, logs, and TLS certs under `/config/mattermost`
- Home Assistant sidebar landing page with health status
- Direct LAN HTTP on port `8065`
- Direct LAN HTTPS on port `8465` with an add-on generated CA certificate
- Bot-friendly defaults: bot account creation, personal access tokens, slash commands, incoming webhooks, and outgoing webhooks are enabled
- Optional nginx Basic Auth for direct ports

## Installation

1. Add this repository to Home Assistant: **Settings > Apps > Install app > Repositories**.
2. Paste the repository URL and click **Add**:
   ```text
   https://github.com/WolframRavenwolf/home-assistant-addons
   ```
3. Find **Mattermost** in the store and click **Install**.
4. Start the add-on.
5. Open `http://homeassistant.local:8065/` or the URL configured in `site_url`.
6. Create the first Mattermost system admin account in the setup wizard.

## Configuration

| Option | Default | Description |
| --- | --- | --- |
| `site_url` | `http://homeassistant.local:8065` | Public LAN URL Mattermost uses for links, redirects, clients, and API callbacks. Set this to the hostname or IP that your browser and bots/agents can reach. |
| `access_password` | empty | Optional nginx Basic Auth password for direct HTTP/HTTPS ports. Username: `mattermost`. Leave empty to rely on Mattermost accounts and tokens only. |
| `env_vars` | `MM_TEAMSETTINGS_SITENAME=Ravenwolf Mattermost`, `MM_EMAILSETTINGS_ENABLEPREVIEWMODEBANNER=false` | Extra Mattermost environment variables applied on every start. Core database, storage, listen address, and Site URL variables are managed by the add-on. |

## Access

Replace `homeassistant.local` with your Home Assistant hostname or IP if needed.

| URL | Description |
| --- | --- |
| `http://homeassistant.local:8065/` | Mattermost web app and REST API over HTTP |
| `https://homeassistant.local:8465/` | Mattermost web app and REST API over HTTPS |
| `https://homeassistant.local:8465/cert/ca.crt` | CA certificate for trusting the self-signed HTTPS certificate |
| `http://homeassistant.local:8065/api/v4/system/ping` | API health check |

For bot or agent integrations, use the direct LAN base URL from `site_url`, then create a bot account or personal access token in Mattermost and configure the integration with that token.

## Storage

All runtime state is persistent and included in Home Assistant backups:

```text
/config/
|-- mattermost/
|   |-- certs/              # generated CA and HTTPS certificates
|   |-- client/plugins/     # client-side plugin assets
|   |-- config/config.json  # persistent Mattermost config
|   |-- data/               # uploaded files
|   |-- logs/               # Mattermost logs
|   |-- plugins/            # server-side plugins
|   `-- .db_password        # generated PostgreSQL password
`-- postgres/               # PostgreSQL data directory
```

## Security Notes

This first version is designed for trusted LAN use. Mattermost accounts and API tokens protect the application itself. The optional `access_password` adds nginx Basic Auth in front of the direct ports, but that also means API clients must send Basic Auth in addition to their Mattermost token.

Before exposing this outside the LAN, put a stronger perimeter in front of it, such as Tailscale, Cloudflare Access, a VPN, or a reverse proxy with proper authentication and TLS.

## Architecture

One Debian Bookworm add-on container runs:

1. PostgreSQL on `127.0.0.1:5432`
2. Mattermost on `127.0.0.1:8066`
3. nginx on Home Assistant ingress port `49170`, direct HTTP `8065`, and direct HTTPS `8465`

The Home Assistant sidebar intentionally serves a landing/status page. Use the direct LAN URL for the actual Mattermost app so web assets, WebSockets, desktop clients, mobile clients, and bot or agent integrations all use the same stable base URL.

## Sources

- Mattermost Linux deployment guide: https://docs.mattermost.com/deployment-guide/server/deploy-linux.html
- Mattermost server releases: https://docs.mattermost.com/product-overview/mattermost-server-releases.html
- Mattermost environment settings: https://docs.mattermost.com/administration-guide/configure/environment-configuration-settings.html
- Mattermost integrations settings: https://docs.mattermost.com/administration-guide/configure/integrations-configuration-settings.html

## License

This Home Assistant add-on is MIT licensed. Mattermost Team Edition is distributed by Mattermost under its own license terms.

---

Copyright (c) 2026 Wolfram Ravenwolf
