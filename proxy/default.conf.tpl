server {
    listen ${LISTEN_PORT};

    # ensure nginx is set to accept any hostname (using _), or that it explicitly includes your EC2 Public IP/Domain Name
    # Allow any host header (best for testing/debugging)
    # server_name _; 
    # server_name ${CUSTOM_DOMAIN};
    server_name ${CUSTOM_DOMAIN} ${CUSTOM_DEV_DOMAIN};

    location /static {
        alias /vol/static;
    }

    location / {
        uwsgi_pass              ${APP_HOST}:${APP_PORT};
        include                 /etc/nginx/uwsgi_params;

        # Add this line to pass the browser's origin header cleanly to Django
        uwsgi_param HTTP_ORIGIN $http_origin;

        client_max_body_size    10M;
    }
}