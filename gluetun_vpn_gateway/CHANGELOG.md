# Changelog

## 0.1.1

- Clarify that NordVPN login/access tokens are not WireGuard private keys.
- Add startup validation with a clearer error when a NordVPN token is pasted into `wireguard_private_key`.
- Document how to convert a NordVPN token to `nordlynx_private_key` locally.

## 0.1.0

- Initial release of the Gluetun VPN Gateway Home Assistant add-on.
- Default profile: NordVPN WireGuard with United States / San Francisco server filters.
- Exposes a LAN-only HTTP CONNECT proxy on port `8888`.
- Supports optional Shadowsocks on port `8388` when explicitly enabled and mapped.
- Keeps Gluetun firewall/kill-switch behavior inside the add-on container.
