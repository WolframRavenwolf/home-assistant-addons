# Ravenwolf Home Assistant Add-ons

A shared Home Assistant add-on repository maintained by Wolfram Ravenwolf.

Add this repository to Home Assistant once, then install any contained add-on from the Add-on Store:

```text
https://github.com/WolframRavenwolf/home-assistant-addons
```

## Add-ons

| Add-on | Slug | Status | Purpose |
| --- | --- | --- | --- |
| Gluetun VPN Gateway | `gluetun_vpn_gateway` | Active | Configurable LAN-only VPN gateway/proxy using Gluetun, defaulting to NordVPN WireGuard with United States / San Francisco server filters, token-to-key caching, HTTP CONNECT, and optional Shadowsocks endpoints for selective client/app routing. |

## Repository layout

```text
repository.yaml
README.md
LICENSE
<addon-slug>/
  config.yaml
  build.yaml
  Dockerfile
  DOCS.md
  translations/
```

Each add-on keeps its own Home Assistant metadata and documentation under its add-on directory. Shared repository-level files live at the root.

## Add-on policy

- Prefer official upstream container images where practical.
- Pin base images or document conscious tracking behavior.
- Keep credentials in Home Assistant add-on options/secrets, never in repository files.
- Keep proxies and service ports LAN-only unless a separate remote-access design is explicitly approved. Use proxy authentication or network-layer access control on untrusted LANs.
- Document default CIDRs/ports as examples, not universal settings; users must adapt them to their network.
- Review Dockerfiles and startup scripts before release; Home Assistant add-ons are privileged infrastructure, not random toy containers.

## Current migration status

- `gluetun_vpn_gateway` was developed here before first publication/install, so no Home Assistant migration is required.
- Existing installed add-ons such as Mattermost should not be blindly moved into this repository without a backup and migration plan, because Home Assistant may treat add-ons from a different repository URL as distinct installations.
