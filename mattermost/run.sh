#!/command/with-contenv bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
if [ ! -f "$OPTIONS_FILE" ]; then
    echo "[run] FATAL: $OPTIONS_FILE not found"
    exit 1
fi

opt() { jq -r ".${1} // empty" "$OPTIONS_FILE"; }
opt_bool() { jq -r ".${1} // false" "$OPTIONS_FILE"; }

SITE_URL=$(opt site_url)
ACCESS_PASSWORD=$(opt access_password)

MATTERMOST_VERSION="${MATTERMOST_VERSION:-unknown}"
MATTERMOST_HOME="/config/mattermost"
MATTERMOST_CONFIG_DIR="$MATTERMOST_HOME/config"
MATTERMOST_CONFIG="$MATTERMOST_CONFIG_DIR/config.json"
MATTERMOST_DATA_DIR="$MATTERMOST_HOME/data"
MATTERMOST_LOG_DIR="$MATTERMOST_HOME/logs"
MATTERMOST_PLUGIN_DIR="$MATTERMOST_HOME/plugins"
MATTERMOST_CLIENT_PLUGIN_DIR="$MATTERMOST_HOME/client/plugins"
MATTERMOST_RUN_DIR="$MATTERMOST_HOME/run"
CERTS_DIR="$MATTERMOST_HOME/certs"
PGDATA="/config/postgres"
DB_NAME="mattermost"
DB_USER="mmuser"
DB_PASSWORD_FILE="$MATTERMOST_HOME/.db_password"
INGRESS_PORT=49170
HTTP_PORT=8065
HTTPS_PORT=8465
MATTERMOST_PORT=8066

MATTERMOST_PID=""
MATTERMOST_TEE_PID=""

prepare_www() {
    mkdir -p /var/www
    chown root:root /var/www
    chmod 755 /var/www
    find /var/www -maxdepth 1 -type f -name '*.html*' -exec chown root:root {} \; -exec chmod 644 {} \;
}

if [ -n "${TZ:-}" ] && [[ "$TZ" != *..* ]] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    echo "[run] Timezone: $TZ"
fi

prepare_www

cat > /etc/nginx/nginx.conf << LOADCONF
worker_processes 1;
pid /var/run/nginx.pid;
error_log stderr warn;
events { worker_connections 64; }
http {
    server {
        listen ${INGRESS_PORT};
        location / { root /var/www; try_files /loading.html =404; }
        location = /health { return 503 "STARTING\\n"; add_header Content-Type text/plain; }
    }
}
LOADCONF
nginx
echo "[run] Loading page active (ingress: $INGRESS_PORT)"

sql_escape() {
    printf "%s" "$1" | sed "s/'/''/g"
}

pg_bindir() {
    local dir
    dir="$(find /usr/lib/postgresql -path '*/bin/pg_ctl' -type f -printf '%h\n' 2>/dev/null | sort -V | tail -1)"
    if [ -n "$dir" ]; then
        printf "%s" "$dir"
        return
    fi
    if command -v pg_ctl >/dev/null 2>&1; then
        dirname "$(command -v pg_ctl)"
    fi
}

site_host() {
    local url="$1"
    url="${url#*://}"
    url="${url%%/*}"
    url="${url%%:*}"
    printf "%s" "${url:-homeassistant.local}"
}

create_password_file() {
    mkdir -p "$MATTERMOST_HOME"
    if [ ! -f "$DB_PASSWORD_FILE" ]; then
        umask 077
        openssl rand -hex 24 > "$DB_PASSWORD_FILE"
        echo "[run] Generated persistent database password"
    fi
}

start_postgres() {
    local pg_bin_dir
    pg_bin_dir="$(pg_bindir)"
    if [ -z "$pg_bin_dir" ]; then
        echo "[run] FATAL: PostgreSQL binaries not found"
        exit 1
    fi

    mkdir -p /run/postgresql "$PGDATA"
    chown -R postgres:postgres /run/postgresql "$PGDATA"
    chmod 775 /run/postgresql
    chmod 700 "$PGDATA"

    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        echo "[run] Initializing PostgreSQL data directory..."
        gosu postgres "$pg_bin_dir/initdb" \
            -D "$PGDATA" \
            --encoding=UTF8 \
            --locale=C.UTF-8 \
            --auth-local=trust \
            --auth-host=scram-sha-256 >/dev/null
        cat >> "$PGDATA/pg_hba.conf" << 'PGHBA'
host all all 127.0.0.1/32 scram-sha-256
host all all ::1/128 scram-sha-256
PGHBA
    fi

    echo "[run] Starting PostgreSQL..."
    gosu postgres "$pg_bin_dir/pg_ctl" \
        -D "$PGDATA" \
        -o "-c listen_addresses='127.0.0.1' -c port=5432 -c unix_socket_directories='/run/postgresql'" \
        -w start >/dev/null
    echo "[run] PostgreSQL started"
}

ensure_database() {
    local db_password db_password_sql
    create_password_file
    db_password="$(cat "$DB_PASSWORD_FILE")"
    db_password_sql="$(sql_escape "$db_password")"

    if ! gosu postgres psql -d postgres -Atqc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
        echo "[run] Creating PostgreSQL role: $DB_USER"
        gosu postgres psql -d postgres -v ON_ERROR_STOP=1 \
            -c "CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${db_password_sql}';" >/dev/null
    else
        gosu postgres psql -d postgres -v ON_ERROR_STOP=1 \
            -c "ALTER ROLE ${DB_USER} WITH PASSWORD '${db_password_sql}';" >/dev/null
    fi

    if ! gosu postgres psql -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
        echo "[run] Creating PostgreSQL database: $DB_NAME"
        gosu postgres createdb -O "$DB_USER" "$DB_NAME"
    fi
    gosu postgres psql -d postgres -v ON_ERROR_STOP=1 \
        -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};" >/dev/null
}

setup_mattermost_storage() {
    mkdir -p \
        "$MATTERMOST_CONFIG_DIR" \
        "$MATTERMOST_DATA_DIR" \
        "$MATTERMOST_LOG_DIR" \
        "$MATTERMOST_PLUGIN_DIR" \
        "$MATTERMOST_CLIENT_PLUGIN_DIR" \
        "$MATTERMOST_RUN_DIR" \
        "$CERTS_DIR"

    if [ ! -f "$MATTERMOST_CONFIG" ]; then
        cp /opt/mattermost/config/config.json "$MATTERMOST_CONFIG"
        echo "[run] Created persistent Mattermost config"
    fi

    chown root:root "$MATTERMOST_HOME"
    chmod 755 "$MATTERMOST_HOME"
    chown -R mattermost:mattermost \
        "$MATTERMOST_CONFIG_DIR" \
        "$MATTERMOST_DATA_DIR" \
        "$MATTERMOST_LOG_DIR" \
        "$MATTERMOST_PLUGIN_DIR" \
        "$MATTERMOST_HOME/client" \
        "$MATTERMOST_RUN_DIR"
    chown root:root "$CERTS_DIR" "$DB_PASSWORD_FILE"
    chmod 700 "$CERTS_DIR"
    chmod 600 "$DB_PASSWORD_FILE"
}

export_mattermost_env() {
    local db_password datasource env_count var_name var_value
    db_password="$(cat "$DB_PASSWORD_FILE")"
    datasource="postgres://${DB_USER}:${db_password}@127.0.0.1:5432/${DB_NAME}?sslmode=disable&connect_timeout=10"

    export MM_CONFIG="$MATTERMOST_CONFIG"
    export MM_SQLSETTINGS_DRIVERNAME="postgres"
    export MM_SQLSETTINGS_DATASOURCE="$datasource"
    export MM_SERVICESETTINGS_LISTENADDRESS="127.0.0.1:${MATTERMOST_PORT}"
    export MM_SERVICESETTINGS_ENABLELOCALMODE="true"
    export MM_SERVICESETTINGS_LOCALMODESOCKETLOCATION="$MATTERMOST_RUN_DIR/mattermost_local.socket"
    export MM_SERVICESETTINGS_ENABLEBOTACCOUNTCREATION="true"
    export MM_SERVICESETTINGS_ENABLEUSERACCESSTOKENS="true"
    export MM_SERVICESETTINGS_ENABLECOMMANDS="true"
    export MM_SERVICESETTINGS_ENABLEINCOMINGWEBHOOKS="true"
    export MM_SERVICESETTINGS_ENABLEOUTGOINGWEBHOOKS="true"
    export MM_EMAILSETTINGS_ENABLEPREVIEWMODEBANNER="false"
    export MM_FILESETTINGS_DRIVERNAME="local"
    export MM_FILESETTINGS_DIRECTORY="$MATTERMOST_DATA_DIR"
    export MM_PLUGINSETTINGS_DIRECTORY="$MATTERMOST_PLUGIN_DIR"
    export MM_PLUGINSETTINGS_CLIENTDIRECTORY="$MATTERMOST_CLIENT_PLUGIN_DIR"
    export MM_LOGSETTINGS_ENABLECONSOLE="true"
    export MM_LOGSETTINGS_CONSOLELEVEL="INFO"
    export MM_LOGSETTINGS_ENABLEFILE="true"
    export MM_LOGSETTINGS_FILELOCATION="$MATTERMOST_LOG_DIR"
    export MM_NOTIFICATIONLOGSETTINGS_ENABLEFILE="true"
    export MM_NOTIFICATIONLOGSETTINGS_FILELOCATION="$MATTERMOST_LOG_DIR"

    if [ -n "$SITE_URL" ]; then
        export MM_SERVICESETTINGS_SITEURL="$SITE_URL"
        echo "[run] Site URL: $SITE_URL"
    fi

    env_count=$(jq '.env_vars // [] | length' "$OPTIONS_FILE" 2>/dev/null || echo 0)
    for i in $(seq 0 $((env_count - 1))); do
        var_name=$(jq -r ".env_vars[$i].name" "$OPTIONS_FILE")
        var_value=$(jq -r ".env_vars[$i].value" "$OPTIONS_FILE")
        case "$var_name" in
            MM_CONFIG|MM_SQLSETTINGS_DRIVERNAME|MM_SQLSETTINGS_DATASOURCE|MM_SERVICESETTINGS_LISTENADDRESS|MM_SERVICESETTINGS_SITEURL|MM_EMAILSETTINGS_ENABLEPREVIEWMODEBANNER|MM_FILESETTINGS_DIRECTORY|MM_PLUGINSETTINGS_DIRECTORY|MM_PLUGINSETTINGS_CLIENTDIRECTORY)
                echo "[run] Warning: skipping managed variable $var_name"
                continue
                ;;
        esac
        if [ -n "$var_name" ] && [ -n "$var_value" ]; then
            export "${var_name}=${var_value}"
            echo "[run] Environment: $var_name set from add-on config"
        fi
    done
}

generate_tls_certificates() {
    if [ -f "$CERTS_DIR/server.crt" ] && [ -f "$CERTS_DIR/server.key" ]; then
        echo "[run] TLS certificates: using existing"
        return
    fi

    echo "[run] Generating self-signed TLS certificates..."
    local lan_ip host
    host="$(site_host "$SITE_URL")"
    lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

    openssl req -x509 -new -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout "$CERTS_DIR/ca.key" -out "$CERTS_DIR/ca.crt" \
        -days 3650 -subj "/CN=Mattermost HA Add-on CA" 2>/dev/null
    openssl req -new -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout "$CERTS_DIR/server.key" -out /tmp/mattermost-server.csr \
        -subj "/CN=${host}" 2>/dev/null
    openssl x509 -req -in /tmp/mattermost-server.csr \
        -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" \
        -CAcreateserial -out "$CERTS_DIR/server.crt" \
        -days 3650 -extfile <(printf "subjectAltName=DNS:%s,DNS:mattermost,DNS:localhost,IP:127.0.0.1,IP:%s" "$host" "$lan_ip") 2>/dev/null
    rm -f /tmp/mattermost-server.csr "$CERTS_DIR/ca.srl"
    chmod 600 "$CERTS_DIR/server.key" "$CERTS_DIR/ca.key"
    echo "[run] TLS certificates generated"
}

render_nginx() {
    local auth_basic_on auth_basic_off host addon_slug

    if [ -n "$ACCESS_PASSWORD" ]; then
        echo "mattermost:$(openssl passwd -apr1 "$ACCESS_PASSWORD")" > /etc/nginx/.htpasswd
        auth_basic_on='auth_basic "Mattermost"; auth_basic_user_file /etc/nginx/.htpasswd;'
        auth_basic_off='auth_basic off;'
        echo "[run] Direct-port Basic Auth enabled (username: mattermost)"
    else
        rm -f /etc/nginx/.htpasswd
        auth_basic_on="# no authentication"
        auth_basic_off=""
    fi

    cp /etc/nginx/nginx.conf.tpl /etc/nginx/nginx.conf
    sed -i \
        -e "s|%%INGRESS_PORT%%|${INGRESS_PORT}|g" \
        -e "s|%%HTTP_PORT%%|${HTTP_PORT}|g" \
        -e "s|%%HTTPS_PORT%%|${HTTPS_PORT}|g" \
        -e "s|%%MATTERMOST_PORT%%|${MATTERMOST_PORT}|g" \
        -e "s|%%CERTS_DIR%%|${CERTS_DIR}|g" \
        -e "s|%%AUTH_BASIC_ON%%|${auth_basic_on}|g" \
        -e "s|%%AUTH_BASIC_OFF%%|${auth_basic_off}|g" \
        /etc/nginx/nginx.conf

    host="$(site_host "$SITE_URL")"
    addon_slug=$(hostname | tr '-' '_')
    cp /var/www/landing.html.tpl /var/www/landing.html
    sed -i \
        -e "s|%%MATTERMOST_VERSION%%|${MATTERMOST_VERSION}|g" \
        -e "s|%%SITE_URL%%|${SITE_URL}|g" \
        -e "s|%%SITE_HOST%%|${host}|g" \
        -e "s|%%HTTPS_PORT%%|${HTTPS_PORT}|g" \
        -e "s|%%ADDON_SLUG%%|${addon_slug}|g" \
        /var/www/landing.html
    prepare_www

    nginx -s reload
    echo "[run] nginx configured (ingress: $INGRESS_PORT, HTTP: $HTTP_PORT, HTTPS: $HTTPS_PORT)"
}

start_mattermost() {
    echo "[run] Starting Mattermost..."
    mkdir -p "$MATTERMOST_LOG_DIR"
    cd /opt/mattermost
    gosu mattermost /opt/mattermost/bin/mattermost 2>&1 | tee -a "$MATTERMOST_LOG_DIR/mattermost.log" &
    MATTERMOST_TEE_PID=$!

    for _ in $(seq 1 20); do
        MATTERMOST_PID=$(pgrep -u mattermost -f "/opt/mattermost/bin/mattermost" | sort -n | tail -1 || true)
        [ -n "$MATTERMOST_PID" ] && break
        sleep 0.5
    done

    if [ -z "$MATTERMOST_PID" ]; then
        echo "[run] FATAL: Mattermost process did not start"
        exit 1
    fi
    echo "[run] Mattermost started (PID: $MATTERMOST_PID, log tee: $MATTERMOST_TEE_PID)"
}

wait_for_mattermost() {
    echo "[run] Waiting for Mattermost API..."
    for _ in $(seq 1 60); do
        if curl -fsS "http://127.0.0.1:${MATTERMOST_PORT}/api/v4/system/ping" >/dev/null 2>&1; then
            echo "[run] Mattermost API is ready"
            return
        fi
        sleep 2
    done
    echo "[run] Warning: Mattermost API did not become ready within 120s"
}

stop_mattermost() {
    if [ -n "$MATTERMOST_PID" ] && kill -0 "$MATTERMOST_PID" 2>/dev/null; then
        kill -TERM "$MATTERMOST_PID" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$MATTERMOST_PID" 2>/dev/null || break
            sleep 1
        done
        kill -0 "$MATTERMOST_PID" 2>/dev/null && kill -9 "$MATTERMOST_PID" 2>/dev/null || true
    fi
    if [ -n "$MATTERMOST_TEE_PID" ] && kill -0 "$MATTERMOST_TEE_PID" 2>/dev/null; then
        kill "$MATTERMOST_TEE_PID" 2>/dev/null || true
    fi
}

shutdown() {
    echo ""
    echo "[run] Shutting down..."
    nginx -s quit 2>/dev/null || true
    stop_mattermost
    if [ -f "$PGDATA/PG_VERSION" ]; then
        gosu postgres "$(pg_bindir)/pg_ctl" -D "$PGDATA" -m fast -w stop >/dev/null 2>&1 || true
    fi
    echo "[run] Shutdown complete"
    exit 0
}

trap shutdown SIGTERM SIGINT

start_postgres
ensure_database
setup_mattermost_storage
export_mattermost_env
generate_tls_certificates
start_mattermost
wait_for_mattermost
render_nginx

echo "---------------------------------------------"
echo " Mattermost Team Edition ${MATTERMOST_VERSION}"
echo " HTTP:  ${SITE_URL}"
echo " HTTPS: https://$(site_host "$SITE_URL"):${HTTPS_PORT}/"
echo " API:   ${SITE_URL}/api/v4/"
echo "---------------------------------------------"

while true; do
    if ! kill -0 "$MATTERMOST_PID" 2>/dev/null; then
        echo "[run] Mattermost exited; restarting in 5s..."
        sleep 5
        start_mattermost
    fi
    sleep 5
done
