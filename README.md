# Wolfram Ravenwolf's Apps

A shared Home Assistant apps repository maintained by Wolfram Ravenwolf.

These apps are maintained primarily for personal use, but are published for anyone who finds them useful.

Home Assistant labels this area as **Apps** and the repository browser as the **App Store**. This repository follows that UI wording for the collection while individual packages may still use Home Assistant's add-on terminology where it is technically accurate.

In Home Assistant, open **Settings > Apps > Install app > Repositories** and add this repository once:

```text
https://github.com/WolframRavenwolf/home-assistant-addons
```

## Apps

| App | Slug | Status | Purpose |
| --- | --- | --- | --- |
| [Gluetun VPN Gateway](gluetun_vpn_gateway/README.md) | `gluetun_vpn_gateway` | Active | Configurable LAN-only VPN gateway/proxy using Gluetun, defaulting to NordVPN WireGuard with United States / San Francisco server filters, token-to-key caching, HTTP CONNECT, and optional Shadowsocks endpoints for selective client/app routing. |
| [Mattermost](mattermost/README.md) | `mattermost` | Active | Mattermost Team Edition with built-in PostgreSQL, persistent storage, Home Assistant sidebar landing page, direct LAN HTTP/HTTPS access, and bot-friendly defaults for internal use. |

## Repository layout

```text
repository.yaml
README.md
LICENSE
<app-slug>/
  README.md
  DOCS.md
  config.yaml
  build.yaml
  Dockerfile
  translations/
```

Each app keeps its own Home Assistant add-on metadata and documentation under its app directory. Shared repository-level files live at the root.

## App policy

- Prefer official upstream container images where practical.
- Pin base images or document conscious tracking behavior.
- Keep credentials in Home Assistant app options/secrets, never in repository files.
- Keep proxies and service ports LAN-only unless a separate remote-access design is explicitly approved. Use proxy authentication or network-layer access control on untrusted LANs.
- Document default CIDRs/ports as examples, not universal settings; users must adapt them to their network.
- Review Dockerfiles and startup scripts before release; Home Assistant apps are privileged infrastructure, not random toy containers.

## License

The Home Assistant app wrapper code in this repository is MIT licensed. Upstream software downloaded, packaged, or run by an app remains governed by its own license terms.
