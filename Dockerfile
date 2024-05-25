FROM golang:1.22.3-alpine3.20 as builder

RUN apk add --no-cache curl

# ffmpeg source - https://github.com/alfg/docker-ffmpeg
ARG FFMPEG_VERSION=7.0
ARG PREFIX=/opt/ffmpeg
ARG LD_LIBRARY_PATH=/opt/ffmpeg/lib
ARG MAKEFLAGS="-j4"

# FFmpeg build dependencies.
RUN apk update && apk add --update \
  build-base \
  coreutils \
  freetype-dev \
  gcc \
  lame-dev \
  openssl-dev \
  libogg-dev \
  libxcb \
  libass \
  libass-dev \
  libvpx-dev \
  libvorbis-dev \
  libwebp-dev \
  libtheora-dev \
  opus-dev \
  pkgconf \
  pkgconfig \
  rtmpdump-dev \
  wget \
  x264-dev \
  x265-dev \
  yasm

# Get fdk-aac from community.
RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories && \
  apk add --update fdk-aac-dev

# Get ffmpeg source.
RUN cd /tmp/ && \
  wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz && \
  tar zxf ffmpeg-${FFMPEG_VERSION}.tar.gz && rm ffmpeg-${FFMPEG_VERSION}.tar.gz

# Compile ffmpeg.
RUN cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
  ./configure \
  --enable-version3 \
  --enable-gpl \
  --enable-nonfree \
  --enable-small \
  --enable-libmp3lame \
  --enable-openssl \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libopus \
  --enable-libfdk-aac \
  --enable-libass \
  --enable-libwebp \
  --enable-librtmp \
  --enable-postproc \
  --enable-libfreetype \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --extra-cflags="-I${PREFIX}/include" \
  --extra-ldflags="-L${PREFIX}/lib" \
  --extra-libs="-lpthread -lm" \
  --prefix="${PREFIX}" && \
  make && make install && make distclean

# Cleanup.
RUN rm -rf /var/cache/apk/* /tmp/*

WORKDIR /app

COPY src src
COPY templates templates
COPY go.mod go.mod

RUN go mod download
RUN go mod tidy
RUN go build -x -o media-roller ./src

# youtube-dl needs python
FROM python:3.8.1-alpine3.11

# This is where the downloaded files will be saved in the container.
ENV MR_DOWNLOAD_DIR="/download"
ENV PATH=/opt/ffmpeg/bin:$PATH

RUN apk add --update --no-cache \
  curl \
  ca-certificates \
  openssl \
  pcre \
  lame \
  libogg \
  libass \
  libvpx \
  libvorbis \
  libwebp \
  libtheora \
  opus \
  rtmpdump \
  x264-dev \
  x265-dev

COPY --from=builder /app/media-roller /app/media-roller
COPY --from=builder /opt/ffmpeg /opt/ffmpeg
COPY --from=builder /usr/lib/libfdk-aac.so.2 /usr/lib/libfdk-aac.so.2
COPY templates /app/templates
COPY static /app/static

WORKDIR /app

RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/youtube-dl && \
   chmod a+rx /usr/local/bin/youtube-dl && \
   youtube-dl --version

CMD /app/media-roller
