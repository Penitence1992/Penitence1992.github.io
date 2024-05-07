FROM node:14.17.0-alpine AS build

WORKDIR /app

COPY . /app/
RUN yarn install && hexo clean && hexo generate


FROM nginx:1.26.0-alpine

COPY --from=build /app/public/ /usr/share/nginx/html

COPY --from=build /app/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/nginx/default.conf /etc/nginx/conf.d/default.conf

WORKDIR /usr/share/nginx/html

EXPOSE 80
