FROM nginx:alpine

COPY ./docker-entrypoint.sh /docker-entrypoint.sh
COPY ./nginx.conf.template /etc/nginx/conf.d/default.conf.template

RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["nginx", "-g", "daemon off;"]
