# Gluetun VPN Gateway

LAN-only Home Assistant add-on that runs [Gluetun](https://github.com/qdm12/gluetun) as a configurable VPN gateway/proxy for selected LAN clients, apps, browser profiles, and CLI tools.

The default profile is ready for a NordVPN San Francisco egress setup:

- Provider: `nordvpn`
- VPN type: `wireguard`
- Country filter: `United States`
- City filter: `San Francisco`
- HTTP CONNECT proxy: `8888/tcp`

With the default profile, enter either `nordvpn_access_token` or `wireguard_private_key`, then start the add-on. If you provide the NordVPN token, the add-on exchanges it for `nordlynx_private_key` at startup, caches the fetched key by default under add-on data, and passes only that WireGuard private key to Gluetun. After the first successful start, you can remove the token and keep using the cached key.

See [`DOCS.md`](DOCS.md) for installation, configuration, proxy-auth options, and verification steps.

## Security

Keep the proxy LAN-only. Do not port-forward it and do not expose it through public tunnels. On untrusted LANs, set `http_proxy_user` and `http_proxy_password`, or use network-layer access control.
