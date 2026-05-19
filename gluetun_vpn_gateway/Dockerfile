ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apk add --no-cache jq ca-certificates tzdata \
    && mkdir -p /var/www /config/gluetun /run/secrets

COPY run.sh /run.sh
COPY landing.html.tpl /var/www/landing.html.tpl

RUN chmod +x /run.sh \
    && chmod 755 /var/www \
    && chmod 644 /var/www/landing.html.tpl \
    && chmod 700 /run/secrets

ENTRYPOINT ["/run.sh"]
