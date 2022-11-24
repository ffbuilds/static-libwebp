# syntax=docker/dockerfile:1

# bump: libwebp /LIBWEBP_VERSION=([\d.]+)/ https://github.com/webmproject/libwebp.git|*
# bump: libwebp after ./hashupdate Dockerfile LIBWEBP $LATEST
# bump: libwebp link "Release notes" https://github.com/webmproject/libwebp/releases/tag/v$LATEST
# bump: libwebp link "Source diff $CURRENT..$LATEST" https://github.com/webmproject/libwebp/compare/v$CURRENT..v$LATEST
ARG LIBWEBP_VERSION=1.2.4
ARG LIBWEBP_URL="https://github.com/webmproject/libwebp/archive/v$LIBWEBP_VERSION.tar.gz"
ARG LIBWEBP_SHA256=dfe7bff3390cd4958da11e760b65318f0a48c32913e4d5bc5e8d55abaaa2d32e

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBWEBP_URL
ARG LIBWEBP_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libwebp.tar.gz "$LIBWEBP_URL" && \
  echo "$LIBWEBP_SHA256  libwebp.tar.gz" | sha256sum --status -c - && \
  mkdir libwebp && \
  tar xf libwebp.tar.gz -C libwebp --strip-components=1 && \
  rm libwebp.tar.gz && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/libwebp/ /tmp/libwebp/
WORKDIR /tmp/libwebp
RUN \
  apk add --no-cache --virtual build \
    build-base autoconf automake libtool pkgconf && \
  ./autogen.sh && \
  ./configure --disable-shared --enable-static --with-pic --enable-libwebpmux --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path libwebp && \
  pkg-config --exists --modversion --path libwebpmux && \
  ar -t /usr/local/lib/libwebp.a && \
  ar -t /usr/local/lib/libwebpmux.a && \
  readelf -h /usr/local/lib/libwebp.a && \
  readelf -h /usr/local/lib/libwebpmux.a && \
  # Cleanup
  apk del build

FROM scratch
ARG LIBWEBP_VERSION
COPY --from=build /usr/local/lib/pkgconfig/libwebp*.pc /usr/local/lib/pkgconfig/
COPY --from=build /usr/local/lib/libwebp*.a /usr/local/lib/
COPY --from=build /usr/local/include/webp/ /usr/local/include/webp/
