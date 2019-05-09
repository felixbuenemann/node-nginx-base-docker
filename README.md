This Docker image contains the following components:

Stable NGINX 1.16 with the following features:

* HTTP/2
* SSL with ALPN support (using OpenSSL)
* Gzip Compression via [Cloudflare's Zlib fork](https://github.com/cloudflare/zlib)
* Brotli Compression using an [ngx\_brotli fork](https://github.com/felixbuenemann/ngx_brotli/tree/fix-static-brotli-build) with brotli 1.0
* Geoip
* Accept-Language support via [accept\_language\_module](https://github.com/giom/nginx_accept_language_module)

Node.js v8 with NPM, Yarn and Full-ICU pre-installed.

It also contains the following tools:

* `forego` for running multiple processes
* `envsubst` for generating configs from environment variables

This is a base image that should be consumed from custom images that contain the
nginx.conf, Procfile, npm packages etc. to build the full app.

See [Dockerfile](Dockerfile) for details.
