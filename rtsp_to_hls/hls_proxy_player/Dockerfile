FROM nginx:alpine

COPY ./docker-entrypoint.sh /docker-entrypoint.sh
COPY ./player.html.template /etc/nginx/html/player.html.template
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["nginx", "-g", "daemon off;"]
