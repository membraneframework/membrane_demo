#!/bin/sh
set -eu

envsubst '${PLAYER_BASE_URL}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

exec "$@"
