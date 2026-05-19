# Gluetun Home Assistant Add-on

> LAN-only VPN gateway/proxy add-on for selective routing from devices such as a MacBook, built around [Gluetun](https://github.com/qdm12/gluetun).

This add-on runs Gluetun inside Home Assistant and exposes local proxy endpoints through a configurable VPN tunnel. It is designed for cases where only specific apps or browser profiles should use an alternate egress path while latency-sensitive apps such as Zoom, Teams, Meet, or normal browsing keep using the regular LAN gateway.

The bundled defaults provide a ready-to-use example profile — NordVPN WireGuard with `United States` + `San Francisco` server filters — but the provider, tunnel type, country/city/server filters, proxy options, and advanced Gluetun environment variables remain configurable for other gateways.

## Features

- Gluetun `v3.41.1` base image, pinned for reproducible builds.
- Generic Gluetun provider configuration; defaults to NordVPN WireGuard + `server_countries: United States` + `server_cities: San Francisco` as an example profile.
- WireGuard mode by default, using a provider private key.
- OpenVPN mode remains available for providers or setups requiring service credentials.
- HTTP CONNECT proxy on port `8888` for Codex, browsers, CLIs, and apps with proxy support.
- Optional Shadowsocks TCP/UDP proxy on port `8388`.
- Gluetun firewall/kill-switch remains active; proxy traffic should not fall back to the normal WAN when VPN fails.
- HA ingress landing page with copy-paste proxy examples.
- Persistent Gluetun server cache/public IP files under `/config/gluetun`.

## Installation

1. Add this repository to Home Assistant: **Settings → Add-ons → Add-on Store → Repositories**.
2. Paste the repository URL:
   ```text
   https://github.com/WolframRavenwolf/home-assistant-addons
   ```
3. Install **Gluetun VPN Gateway**.
4. For the default NordVPN San Francisco profile, enter your NordVPN WireGuard private key in `wireguard_private_key` before starting. For other providers/tunnel types, adjust the provider/server options and credentials first.
5. Start the add-on.
6. Configure only the apps that should use this VPN gateway to use `http://homeassistant.local:8888` or your Home Assistant LAN IP.

## Default profile: NordVPN WireGuard with San Francisco egress

The default options are set so the add-on targets NordVPN WireGuard in the United States, filtered to San Francisco. For this default profile, the only VPN credential you need to enter is your NordVPN WireGuard private key.

| Option | Example value |
| --- | --- |
| `vpn_service_provider` | `nordvpn` |
| `vpn_type` | `wireguard` |
| `server_countries` | `United States` |
| `server_cities` | `San Francisco` |
| `wireguard_private_key` | NordVPN WireGuard private key |
| `http_proxy` | `true` |
| `firewall_outbound_subnets` | Your trusted LAN CIDR, for example `192.168.178.0/24` |

If you switch NordVPN to `openvpn`, NordVPN requires **manual setup service credentials**, not the normal account email/password. In that mode, set `openvpn_user` and `openvpn_password` instead of `wireguard_private_key`.

For other providers, use the provider identifier and options expected by Gluetun, then adjust the server filters or advanced `env_vars` as needed.

## MacBook / Codex example

Create or update `~/.codex/.env` on the MacBook:

```bash
mkdir -p ~/.codex
cat > ~/.codex/.env <<'EOF'
http_proxy=http://homeassistant.local:8888
https_proxy=http://homeassistant.local:8888
HTTP_PROXY=http://homeassistant.local:8888
HTTPS_PROXY=http://homeassistant.local:8888
no_proxy=localhost,127.0.0.1,::1
NO_PROXY=localhost,127.0.0.1,::1
EOF
```

Restart Codex Desktop completely after editing this file.

For browser-only testing, launch a separate Chrome profile:

```bash
open -na "Google Chrome" --args \
  --user-data-dir="$HOME/Library/Application Support/Chrome-VPN-Proxy" \
  --proxy-server="http://homeassistant.local:8888"
```

## Verification

From a proxied app/profile:

```bash
curl -x http://homeassistant.local:8888 https://ipinfo.io/json
curl -x http://homeassistant.local:8888 https://ifconfig.co/json
```

Expected result: public IP geolocates to the selected VPN endpoint, for example United States / San Francisco or a nearby NordVPN endpoint with the default profile.

Also check DNS/IP leaks with a browser profile pointed at the proxy:

- <https://ipleak.net>
- <https://dnsleaktest.com>

## Security notes

- Keep this proxy LAN-only. Do not port-forward it and do not expose it through Tailscale Funnel or public reverse proxies.
- Optional HTTP proxy authentication is supported, but some clients and browsers handle proxy auth poorly. Prefer LAN-only exposure plus device-level discipline for the first version; on untrusted LANs, set `http_proxy_user` and `http_proxy_password` or restrict access at the network layer.
- `firewall_outbound_subnets` must match your actual trusted LAN CIDR if the add-on needs to talk back to LAN clients; the default `192.168.178.0/24` is only an example profile.
- Optional Shadowsocks ports are disabled by default in Home Assistant (`null` host mappings). To expose Shadowsocks, assign `8388/tcp` and `8388/udp` in the add-on network settings and set `shadowsocks: true` plus a strong password.
- Do not change Home Assistant's own default gateway; this add-on should isolate VPN routing inside the container.
- If `http_proxy_user` is set, `http_proxy_password` must also be set.
- If Shadowsocks is enabled, set a strong `shadowsocks_password`.

## Sources

- Gluetun: <https://github.com/qdm12/gluetun>
- Gluetun provider docs: <https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers>
- Gluetun LAN device docs: <https://github.com/qdm12/gluetun-wiki/blob/main/setup/connect-a-lan-device-to-gluetun.md>
- Gluetun HTTP proxy options: <https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/http-proxy.md>
- Gluetun Shadowsocks options: <https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/shadowsocks.md>
- Gluetun firewall options: <https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/firewall.md>

## License

This Home Assistant add-on wrapper is MIT licensed. Gluetun is distributed separately under its own license terms.
