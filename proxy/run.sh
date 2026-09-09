#!/bin/sh

set -e

#envsubst < /etc/nginx/default.conf.tpl > /etc/nginx/conf.d/default.conf
envsubst '\$LISTEN_PORT \$APP_HOST \$APP_PORT \$EC2_ELASTIC_IP \$CUSTOM_DOMAIN' < /etc/nginx/default.conf.tpl > /etc/nginx/conf.d/default.conf
nginx -g 'daemon off;'