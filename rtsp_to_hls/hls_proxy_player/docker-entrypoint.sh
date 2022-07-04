#!/bin/sh
set -eu

envsubst '${SERVER_BASE_URL}' < /etc/nginx/html/player.html.template > /etc/nginx/html/index.html

exec "$@"
