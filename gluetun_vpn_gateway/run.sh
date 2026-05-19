#!/bin/sh
set -eu

OPTIONS_FILE="/data/options.json"
INGRESS_PORT=8099
HTTP_PROXY_PORT=8888
SHADOWSOCKS_PORT=8388
CONFIG_DIR="/config/gluetun"
LANDING_TEMPLATE="/var/www/landing.html.tpl"
LANDING_PAGE="/var/www/landing.html"

fatal() {
    echo "[gluetun-vpn-gateway] FATAL: $*" >&2
    exit 1
}

opt() {
    jq -r ".${1} // empty" "$OPTIONS_FILE"
}

opt_bool() {
    [ "$(jq -r ".${1} // false" "$OPTIONS_FILE")" = "true" ]
}

onoff() {
    if [ "$1" = "true" ]; then printf 'on'; else printf 'off'; fi
}

set_if_nonempty() {
    var="$1"
    value="$2"
    if [ -n "$value" ]; then
        export "$var=$value"
        echo "[gluetun-vpn-gateway] $var configured"
    fi
}

write_secret() {
    path="$1"
    value="$2"
    [ -n "$value" ] || return 0
    mkdir -p /run/secrets
    umask 077
    printf '%s' "$value" > "$path"
    chmod 600 "$path"
}

sed_escape() {
    printf '%s' "$1" | sed 's/[&|]/\\&/g'
}

html_escape() {
    printf '%s' "$1" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g' \
        -e "s/'/\&#39;/g"
}

validate_extra_ports() {
    ports="$1"
    [ -z "$ports" ] && return 0
    case "$ports" in
        *[!0-9,]*|,*|*,|*,,*) fatal "extra_input_ports must be a comma-separated list of ports" ;;
    esac
    old_ifs="$IFS"
    IFS=','
    for port in $ports; do
        [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null || fatal "invalid extra input port: $port"
    done
    IFS="$old_ifs"
}

validate_wireguard_private_key_hint() {
    key="$1"
    [ -n "$key" ] || return 0
    key_len=${#key}
    if [ "$VPN_SERVICE_PROVIDER" = "nordvpn" ] && [ "$VPN_TYPE" = "wireguard" ] && [ "$key_len" -eq 64 ]; then
        fatal "wireguard_private_key looks like a NordVPN access token (${key_len} chars), not a WireGuard private key. Convert it locally with: curl -sS -u 'token:<token>' https://api.nordvpn.com/v1/users/services/credentials | jq -r '.nordlynx_private_key'"
    fi
    if [ "$key_len" -ne 44 ]; then
        fatal "wireguard_private_key must be the provider WireGuard private key, usually 44 base64 characters ending with '='. Got ${key_len} characters. A NordVPN login/access token is not valid here."
    fi
}

is_managed_env() {
    case "$1" in
        VPN_SERVICE_PROVIDER|VPN_TYPE|OPENVPN_USER|OPENVPN_PASSWORD|OPENVPN_USER_SECRETFILE|OPENVPN_PASSWORD_SECRETFILE|OPENVPN_PROTOCOL|WIREGUARD_PRIVATE_KEY|WIREGUARD_PRIVATE_KEY_SECRETFILE|SERVER_COUNTRIES|SERVER_REGIONS|SERVER_CITIES|SERVER_HOSTNAMES|SERVER_CATEGORIES|SERVER_NUMBER|HTTPPROXY|HTTPPROXY_LISTENING_ADDRESS|HTTPPROXY_USER|HTTPPROXY_PASSWORD|HTTPPROXY_USER_SECRETFILE|HTTPPROXY_PASSWORD_SECRETFILE|HTTPPROXY_STEALTH|SHADOWSOCKS|SHADOWSOCKS_LISTENING_ADDRESS|SHADOWSOCKS_PASSWORD|SHADOWSOCKS_PASSWORD_SECRETFILE|SHADOWSOCKS_CIPHER|FIREWALL_INPUT_PORTS|FIREWALL_OUTBOUND_SUBNETS|FIREWALL_ENABLED_DISABLING_IT_SHOOTS_YOU_IN_YOUR_FOOT|HEALTH_SERVER_ADDRESS|HTTP_CONTROL_SERVER_ADDRESS|STORAGE_FILEPATH|PUBLICIP_FILE|LOG_LEVEL)
            return 0
            ;;
    esac
    return 1
}

apply_extra_env_vars() {
    count="$(jq '.env_vars // [] | length' "$OPTIONS_FILE")"
    [ "$count" -gt 0 ] || return 0
    i=0
    while [ "$i" -lt "$count" ]; do
        name="$(jq -r ".env_vars[$i].name // empty" "$OPTIONS_FILE")"
        value="$(jq -r ".env_vars[$i].value // empty" "$OPTIONS_FILE")"
        i=$((i + 1))
        [ -n "$name" ] || continue
        if is_managed_env "$name"; then
            echo "[gluetun-vpn-gateway] Warning: skipping managed environment variable $name"
            continue
        fi
        export "$name=$value"
        echo "[gluetun-vpn-gateway] Extra environment variable configured: $name"
    done
}

render_landing_page() {
    host_hint="$(opt host_hint)"
    [ -n "$host_hint" ] || host_hint="homeassistant.local"
    cp "$LANDING_TEMPLATE" "$LANDING_PAGE"
    sed -i \
        -e "s|%%HOST_HINT%%|$(sed_escape "$(html_escape "$host_hint")")|g" \
        -e "s|%%HTTP_PROXY_PORT%%|${HTTP_PROXY_PORT}|g" \
        -e "s|%%SHADOWSOCKS_PORT%%|${SHADOWSOCKS_PORT}|g" \
        -e "s|%%SERVER_COUNTRIES%%|$(sed_escape "$(html_escape "${SERVER_COUNTRIES:-}")")|g" \
        -e "s|%%SERVER_CITIES%%|$(sed_escape "$(html_escape "${SERVER_CITIES:-}")")|g" \
        -e "s|%%VPN_SERVICE_PROVIDER%%|$(sed_escape "$(html_escape "${VPN_SERVICE_PROVIDER:-}")")|g" \
        -e "s|%%VPN_TYPE%%|$(sed_escape "$(html_escape "${VPN_TYPE:-}")")|g" \
        "$LANDING_PAGE"
}

start_landing_server() {
    render_landing_page
    if command -v busybox >/dev/null 2>&1; then
        busybox httpd -f -p "0.0.0.0:${INGRESS_PORT}" -h /var/www &
    else
        httpd -f -p "0.0.0.0:${INGRESS_PORT}" -h /var/www &
    fi
    echo "[gluetun-vpn-gateway] Landing page listening on ingress port ${INGRESS_PORT}"
}

[ -f "$OPTIONS_FILE" ] || fatal "$OPTIONS_FILE not found"
mkdir -p "$CONFIG_DIR" /run/secrets /var/www
chmod 700 /run/secrets

VPN_SERVICE_PROVIDER="$(opt vpn_service_provider)"
VPN_TYPE="$(opt vpn_type)"
SERVER_COUNTRIES="$(opt server_countries)"
SERVER_REGIONS="$(opt server_regions)"
SERVER_CITIES="$(opt server_cities)"
SERVER_HOSTNAMES="$(opt server_hostnames)"
SERVER_CATEGORIES="$(opt server_categories)"
SERVER_NUMBER="$(opt server_number)"
OPENVPN_USER_VALUE="$(opt openvpn_user)"
OPENVPN_PASSWORD_VALUE="$(opt openvpn_password)"
OPENVPN_PROTOCOL_VALUE="$(opt openvpn_protocol)"
WIREGUARD_PRIVATE_KEY_VALUE="$(opt wireguard_private_key)"
HTTP_PROXY_USER_VALUE="$(opt http_proxy_user)"
HTTP_PROXY_PASSWORD_VALUE="$(opt http_proxy_password)"
SHADOWSOCKS_PASSWORD_VALUE="$(opt shadowsocks_password)"
SHADOWSOCKS_CIPHER_VALUE="$(opt shadowsocks_cipher)"
FIREWALL_OUTBOUND_SUBNETS_VALUE="$(opt firewall_outbound_subnets)"
EXTRA_INPUT_PORTS="$(opt extra_input_ports | tr -d '[:space:]')"
LOG_LEVEL_VALUE="$(opt log_level)"

[ -n "$VPN_SERVICE_PROVIDER" ] || fatal "vpn_service_provider must not be empty"
[ -n "$VPN_TYPE" ] || fatal "vpn_type must not be empty"

case "$VPN_TYPE" in
    openvpn|wireguard) ;;
    *) fatal "vpn_type must be openvpn or wireguard" ;;
esac

if [ "$VPN_SERVICE_PROVIDER" = "nordvpn" ]; then
    if [ "$VPN_TYPE" = "openvpn" ]; then
        [ -n "$OPENVPN_USER_VALUE" ] || fatal "openvpn_user is required for NordVPN OpenVPN. Use NordVPN service credentials, not your account email."
        [ -n "$OPENVPN_PASSWORD_VALUE" ] || fatal "openvpn_password is required for NordVPN OpenVPN. Use NordVPN service credentials, not your account password."
    else
        [ -n "$WIREGUARD_PRIVATE_KEY_VALUE" ] || fatal "wireguard_private_key is required for NordVPN WireGuard."
        validate_wireguard_private_key_hint "$WIREGUARD_PRIVATE_KEY_VALUE"
    fi
fi

if opt_bool http_proxy; then
    if { [ -n "$HTTP_PROXY_USER_VALUE" ] && [ -z "$HTTP_PROXY_PASSWORD_VALUE" ]; } || { [ -z "$HTTP_PROXY_USER_VALUE" ] && [ -n "$HTTP_PROXY_PASSWORD_VALUE" ]; }; then
        fatal "http_proxy_user and http_proxy_password must be set together, or both left empty"
    fi
fi

if opt_bool shadowsocks; then
    [ -n "$SHADOWSOCKS_PASSWORD_VALUE" ] || fatal "shadowsocks_password is required when shadowsocks is enabled"
fi

validate_extra_ports "$EXTRA_INPUT_PORTS"

export VPN_SERVICE_PROVIDER="$VPN_SERVICE_PROVIDER"
export VPN_TYPE="$VPN_TYPE"
export OPENVPN_PROTOCOL="$OPENVPN_PROTOCOL_VALUE"
set_if_nonempty SERVER_COUNTRIES "$SERVER_COUNTRIES"
set_if_nonempty SERVER_REGIONS "$SERVER_REGIONS"
set_if_nonempty SERVER_CITIES "$SERVER_CITIES"
set_if_nonempty SERVER_HOSTNAMES "$SERVER_HOSTNAMES"
set_if_nonempty SERVER_CATEGORIES "$SERVER_CATEGORIES"
set_if_nonempty SERVER_NUMBER "$SERVER_NUMBER"
set_if_nonempty LOG_LEVEL "$LOG_LEVEL_VALUE"

export OPENVPN_USER_SECRETFILE=
export OPENVPN_PASSWORD_SECRETFILE=
export WIREGUARD_PRIVATE_KEY_SECRETFILE=
export HTTPPROXY_USER_SECRETFILE=
export HTTPPROXY_PASSWORD_SECRETFILE=
export SHADOWSOCKS_PASSWORD_SECRETFILE=

if [ -n "$OPENVPN_USER_VALUE" ]; then
    write_secret /run/secrets/openvpn_user "$OPENVPN_USER_VALUE"
    export OPENVPN_USER_SECRETFILE=/run/secrets/openvpn_user
fi
if [ -n "$OPENVPN_PASSWORD_VALUE" ]; then
    write_secret /run/secrets/openvpn_password "$OPENVPN_PASSWORD_VALUE"
    export OPENVPN_PASSWORD_SECRETFILE=/run/secrets/openvpn_password
fi
if [ -n "$WIREGUARD_PRIVATE_KEY_VALUE" ]; then
    write_secret /run/secrets/wireguard_private_key "$WIREGUARD_PRIVATE_KEY_VALUE"
    export WIREGUARD_PRIVATE_KEY_SECRETFILE=/run/secrets/wireguard_private_key
fi
if [ -n "$HTTP_PROXY_USER_VALUE" ]; then
    write_secret /run/secrets/httpproxy_user "$HTTP_PROXY_USER_VALUE"
    export HTTPPROXY_USER_SECRETFILE=/run/secrets/httpproxy_user
fi
if [ -n "$HTTP_PROXY_PASSWORD_VALUE" ]; then
    write_secret /run/secrets/httpproxy_password "$HTTP_PROXY_PASSWORD_VALUE"
    export HTTPPROXY_PASSWORD_SECRETFILE=/run/secrets/httpproxy_password
fi
if [ -n "$SHADOWSOCKS_PASSWORD_VALUE" ]; then
    write_secret /run/secrets/shadowsocks_password "$SHADOWSOCKS_PASSWORD_VALUE"
    export SHADOWSOCKS_PASSWORD_SECRETFILE=/run/secrets/shadowsocks_password
fi

if opt_bool http_proxy; then
    export HTTPPROXY=on
else
    export HTTPPROXY=off
fi
export HTTPPROXY_LISTENING_ADDRESS=":${HTTP_PROXY_PORT}"
if opt_bool http_proxy_stealth; then
    export HTTPPROXY_STEALTH=on
else
    export HTTPPROXY_STEALTH=off
fi

if opt_bool shadowsocks; then
    export SHADOWSOCKS=on
else
    export SHADOWSOCKS=off
fi
export SHADOWSOCKS_LISTENING_ADDRESS=":${SHADOWSOCKS_PORT}"
set_if_nonempty SHADOWSOCKS_CIPHER "$SHADOWSOCKS_CIPHER_VALUE"

input_ports="$INGRESS_PORT"
if opt_bool http_proxy; then
    input_ports="$input_ports,$HTTP_PROXY_PORT"
fi
if opt_bool shadowsocks; then
    input_ports="$input_ports,$SHADOWSOCKS_PORT"
fi
if [ -n "$EXTRA_INPUT_PORTS" ]; then
    input_ports="$input_ports,$EXTRA_INPUT_PORTS"
fi
export FIREWALL_INPUT_PORTS="$input_ports"
set_if_nonempty FIREWALL_OUTBOUND_SUBNETS "$FIREWALL_OUTBOUND_SUBNETS_VALUE"

export HTTP_CONTROL_SERVER_ADDRESS="127.0.0.1:8000"
export HEALTH_SERVER_ADDRESS="127.0.0.1:9999"
export STORAGE_FILEPATH="${CONFIG_DIR}/servers.json"
export PUBLICIP_FILE="${CONFIG_DIR}/public_ip"

apply_extra_env_vars
start_landing_server

echo "---------------------------------------------"
echo " Gluetun VPN Gateway Home Assistant Add-on"
echo " Provider:     ${VPN_SERVICE_PROVIDER}"
echo " VPN type:     ${VPN_TYPE}"
echo " Server countries: ${SERVER_COUNTRIES:-any}"
echo " Server cities:    ${SERVER_CITIES:-any}"
echo " HTTP proxy:   ${HTTPPROXY} on :${HTTP_PROXY_PORT}"
echo " Shadowsocks:  ${SHADOWSOCKS} on :${SHADOWSOCKS_PORT}"
echo " Input ports:  ${FIREWALL_INPUT_PORTS}"
echo " LAN subnets:  ${FIREWALL_OUTBOUND_SUBNETS_VALUE:-none}"
echo "---------------------------------------------"

exec /gluetun-entrypoint
