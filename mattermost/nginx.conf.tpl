worker_processes 1;
pid /var/run/nginx.pid;
error_log stderr warn;

events {
    worker_connections 512;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    client_body_buffer_size 16m;
    client_max_body_size 0;

    log_format minimal '$remote_addr - $request_uri $status';
    access_log /dev/stdout minimal;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }

    upstream mattermost_app {
        server 127.0.0.1:%%MATTERMOST_PORT%%;
    }

    server {
        listen %%INGRESS_PORT%%;
        server_name _;

        location = / {
            root /var/www;
            try_files /landing.html =404;
            add_header Cache-Control "no-cache";
        }

        location = /health {
            access_log off;
            proxy_pass http://mattermost_app/api/v4/system/ping;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
        }
    }

    server {
        listen %%HTTP_PORT%%;
        server_name _;

        %%AUTH_BASIC_ON%%

        location = /health {
            %%AUTH_BASIC_OFF%%
            access_log off;
            proxy_pass http://mattermost_app/api/v4/system/ping;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
        }

        location / {
            proxy_pass http://mattermost_app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-Proto http;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
        }
    }

    server {
        listen %%HTTPS_PORT%% ssl;
        server_name _;

        ssl_certificate %%CERTS_DIR%%/server.crt;
        ssl_certificate_key %%CERTS_DIR%%/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        %%AUTH_BASIC_ON%%

        location = /cert/ca.crt {
            %%AUTH_BASIC_OFF%%
            alias %%CERTS_DIR%%/ca.crt;
            default_type application/x-x509-ca-cert;
            add_header Content-Disposition 'attachment; filename="mattermost-ca.crt"';
        }

        location = /health {
            %%AUTH_BASIC_OFF%%
            access_log off;
            proxy_pass http://mattermost_app/api/v4/system/ping;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
        }

        location / {
            proxy_pass http://mattermost_app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-Proto https;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
        }
    }
}
