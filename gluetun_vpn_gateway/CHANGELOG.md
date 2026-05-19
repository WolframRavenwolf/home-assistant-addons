# Changelog

## 0.1.3

- Add `cache_fetched_wireguard_key`, enabled by default.
- Cache NordVPN token-fetched `nordlynx_private_key` under add-on data for future starts.
- Allow the steady-state flow: enter `nordvpn_access_token`, start once, remove the token, keep using the cached key.

## 0.1.2

- Add optional `nordvpn_access_token` support for NordVPN WireGuard.
- Exchange the token for `nordlynx_private_key` at startup when `wireguard_private_key` is empty.
- Keep `wireguard_private_key` as the higher-priority static credential path.

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
