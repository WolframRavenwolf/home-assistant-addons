# Changelog

## 0.1.0

- Initial release of the Gluetun VPN Gateway Home Assistant add-on.
- Default profile: NordVPN WireGuard with United States / San Francisco server filters.
- Exposes a LAN-only HTTP CONNECT proxy on port `8888`.
- Supports optional Shadowsocks on port `8388` when explicitly enabled and mapped.
- Keeps Gluetun firewall/kill-switch behavior inside the add-on container.
