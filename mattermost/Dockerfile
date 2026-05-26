ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG MATTERMOST_VERSION=11.6.1
ENV MATTERMOST_VERSION=${MATTERMOST_VERSION}

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gosu \
        jq \
        nginx \
        openssl \
        postgresql \
        postgresql-contrib \
        procps \
        tzdata \
    && rm -rf /var/lib/apt/lists/* /var/lib/postgresql/* /var/log/postgresql/*

RUN useradd --system --user-group --home-dir /opt/mattermost --shell /usr/sbin/nologin mattermost \
    && case "${BUILD_ARCH}" in \
        amd64) MM_ARCH="amd64" ;; \
        aarch64) MM_ARCH="arm64" ;; \
        *) echo "Unsupported BUILD_ARCH: ${BUILD_ARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://releases.mattermost.com/${MATTERMOST_VERSION}/mattermost-team-${MATTERMOST_VERSION}-linux-${MM_ARCH}.tar.gz" \
        -o /tmp/mattermost.tar.gz \
    && tar -xzf /tmp/mattermost.tar.gz -C /opt \
    && rm /tmp/mattermost.tar.gz \
    && mkdir -p /opt/mattermost/data \
    && chown -R mattermost:mattermost /opt/mattermost \
    && chmod -R g+w /opt/mattermost \
    && /opt/mattermost/bin/mattermost version

COPY run.sh /
COPY nginx.conf.tpl /etc/nginx/nginx.conf.tpl
COPY landing.html.tpl /var/www/landing.html.tpl
COPY loading.html /var/www/loading.html

RUN chmod +x /run.sh \
    && mkdir -p /var/www /var/log/nginx /run/nginx /run/postgresql \
    && chown root:root /var/www /var/www/landing.html.tpl /var/www/loading.html \
    && chmod 755 /var/www \
    && chmod 644 /var/www/landing.html.tpl /var/www/loading.html

ENV HOME=/config
WORKDIR /opt/mattermost

CMD ["/run.sh"]
