# Changelog

## 1.0.1

- Replace Gluetun `v3.41.1` with the upstream build from 2026-10-19 at revision `156ccc2659f0a429d29d1f11bdf07229c5c3eba0`.
- Pin separate amd64 and aarch64 base-image manifests in architecture-specific Dockerfiles.
- Include upstream WireGuard, firewall, routing, DNS, and health-check fixes merged after `v3.41.1`, including the fix for connections dropped during firewall setup.

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
