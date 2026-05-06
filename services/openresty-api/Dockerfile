FROM openresty/openresty:alpine

RUN apk add --no-cache ca-certificates curl git openssl perl \
  && opm get openresty/lua-resty-redis \
  && opm get openresty/lua-resty-mysql \
  && opm get ledgetech/lua-resty-http \
  && opm get fffonion/lua-resty-openssl

WORKDIR /usr/local/openresty/nginx

CMD ["openresty", "-g", "daemon off;", "-p", "/usr/local/openresty/nginx", "-c", "conf/nginx.conf"]
