server {
    listen ${LISTEN_PORT};

    # ensure nginx is set to accept any hostname (using _), or that it explicitly includes your EC2 Public IP/Domain Name
    # Allow any host header (best for testing/debugging)
    # server_name _; 

    # OR explicitly state your domain/IP:
    # server_name ://amazonaws.com 54.xx.xx.xx;

    # uncomment this - but maybe replace ec2 elastic ip with cloudfront domain name...?
    server_name ${EC2_ELASTIC_IP} ${CUSTOM_DOMAIN};

    location /static {
        alias /vol/static;
    }

    location / {
        uwsgi_pass              ${APP_HOST}:${APP_PORT};
        include                 /etc/nginx/uwsgi_params;
        client_max_body_size    10M;
    }
}