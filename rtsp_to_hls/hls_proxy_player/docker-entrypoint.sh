#!/bin/sh
set -eu

envsubst '${SERVER_BASE_URL},${HLS_PATH}' < /etc/nginx/html/player.html.template > /etc/nginx/html/index.html

exec "$@"
