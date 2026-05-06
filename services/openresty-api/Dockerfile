FROM openresty/openresty:jammy

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl git openssl perl \
  && opm get openresty/lua-resty-redis \
  && opm get openresty/lua-resty-mysql \
  && opm get ledgetech/lua-resty-http \
  && opm get fffonion/lua-resty-openssl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/ai-audio-api

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;", "-p", "/opt/ai-audio-api", "-c", "conf/nginx.conf"]
