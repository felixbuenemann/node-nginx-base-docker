FROM alpine:3.8
MAINTAINER Felix Buenemann <buenemann@louis.info>

ENV NGINX_VERSION 1.16.0
ENV NGINX_GPG_KEY B0F4253373F8F6F510D42178520A9993A1C052F8
ENV CLOUDFLARE_ZLIB_REF af9ef2e94cb9ffebc8dc6cc6d856e494880d869b
ENV ACCEPT_LANGUAGE_MODULE_REF 2f69842f83dac77f7d98b41a2b31b13b87aeaba7
ENV BROTLI_MODULE_REF 8104036af9cff4b1d34f22d00ba857e2a93a243c
ENV BROTLI_LIBRARY_REF d6d98957ca8ccb1ef45922e978bb10efca0ea541

ADD stack-fix.c /tmp/

RUN set -x \
  && addgroup -g 1000 node \
  && adduser -u 1000 -G node -s /bin/sh -D node \
  && addgroup -S nginx \
  && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
  && apk update && apk upgrade \
  && apk add bash openssl pcre ca-certificates libintl geoip nodejs npm yarn \
  && apk add --virtual .build-deps build-base linux-headers gettext gnupg geoip-dev openssl-dev pcre-dev \
  && gcc  -shared -fPIC /tmp/stack-fix.c -o /usr/local/lib/stack-fix.so \
  && strip /usr/local/lib/stack-fix.so \
  && rm /tmp/stack-fix.c \
  && mkdir -p /tmp/src \
  # get nginx_accept_language_module:
  && cd /tmp/src \
  && wget -O nginx_accept_language_module.tgz https://github.com/giom/nginx_accept_language_module/archive/${ACCEPT_LANGUAGE_MODULE_REF}.tar.gz \
  && tar xzf nginx_accept_language_module.tgz \
  # get ngx_brotli:
  && cd /tmp/src \
  && wget -O ngx_brotli.tgz https://github.com/eustas/ngx_brotli/archive/${BROTLI_MODULE_REF}.tar.gz \
  && tar xzf ngx_brotli.tgz \
  # get brotli lib for ngx_brotli:
  && cd /tmp/src \
  && wget -O brotli.tgz https://github.com/google/brotli/archive/${BROTLI_LIBRARY_REF}.tar.gz \
  && tar xzf brotli.tgz \
  && rmdir ngx_brotli-${BROTLI_MODULE_REF}/deps/brotli \
  && mv brotli-${BROTLI_LIBRARY_REF} ngx_brotli-${BROTLI_MODULE_REF}/deps/brotli \
  # get cloudflare zlib fork:
  && cd /tmp/src \
  && wget -O zlib.tgz https://github.com/cloudflare/zlib/archive/${CLOUDFLARE_ZLIB_REF}.tar.gz \
  && tar xzf zlib.tgz \
  && cd /tmp/src/zlib-${CLOUDFLARE_ZLIB_REF} \
  && make -f Makefile.in distclean \
  # install nginx:
  && cd /tmp/src \
  && wget -O nginx.tgz https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
  && wget -O nginx.tgz.asc https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc \
  && export GNUPGHOME=$PWD \
  && gpg --keyserver hkp://keyserver.ubuntu.com:80 --keyserver-options timeout=10 --recv-keys $NGINX_GPG_KEY \
  && gpg --batch --verify nginx.tgz.asc nginx.tgz \
  && tar xzf nginx.tgz \
  && cd /tmp/src/nginx-${NGINX_VERSION} \
  && ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/nginx.lock \
    --http-log-path=/var/log/nginx/access.log \
    --error-log-path=/var/log/nginx/error.log \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-zlib=/tmp/src/zlib-${CLOUDFLARE_ZLIB_REF} \
    --with-pcre-jit \
    --with-http_ssl_module \
    --with-stream_ssl_module \
    --with-http_stub_status_module \
    --with-http_gzip_static_module \
    --with-http_gunzip_module \
    --with-http_v2_module \
    --with-http_auth_request_module \
    --with-http_realip_module \
    --with-http_geoip_module \
    --add-module=/tmp/src/nginx_accept_language_module-${ACCEPT_LANGUAGE_MODULE_REF} \
    --add-module=/tmp/src/ngx_brotli-${BROTLI_MODULE_REF} \
  && make -s V=0 install \
  # forward request and error logs to docker log collector
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  # move envsubst to /usr/local so it's not deleted
  && cp /usr/bin/envsubst /usr/local/bin/ \
  # remove build files and dependencies
  && rm -rf /tmp/src \
  && apk del --purge .build-deps \
  && rm -rf /var/cache/apk/*

ENV LD_PRELOAD=/usr/local/lib/stack-fix.so

ARG FOREGO_URL=https://bin.equinox.io/a/c6JW1BqJwSa/forego-20170327195458-linux-amd64.tar.gz
ARG FOREGO_SHA256=ebea36e8326cdbc9cca15f946c13eb7b91c73bce61bcc2fd6ae7984e825b81d0
RUN set -x \
  && cd /tmp \
  && wget -O forego.tgz $FOREGO_URL \
  && echo "$FOREGO_SHA256 *forego.tgz" | sha256sum -cs \
  && tar xzf forego.tgz \
  && chmod +x forego \
  && mv forego /usr/local/bin/ \
  && rm forego.tgz

# alpine's nodejs is compiled with small-icu, download full-icu
ENV FULL_ICU_VERSION=1.2.1
RUN su node -c "cd && npm install --silent --no-package-lock --prod full-icu@${FULL_ICU_VERSION}" >/dev/null
ENV NODE_ICU_DATA /home/node/node_modules/full-icu
