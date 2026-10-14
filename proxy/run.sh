#!/bin/sh

set -e

#envsubst < /etc/nginx/default.conf.tpl > /etc/nginx/conf.d/default.conf
envsubst '\$LISTEN_PORT \$APP_HOST \$APP_PORT \$CUSTOM_DOMAIN \$CUSTOM_DEV_DOMAIN \$CLOUDFRONT_SECRET_TOKEN' < /etc/nginx/default.conf.tpl > /etc/nginx/conf.d/default.conf
nginx -g 'daemon off;'