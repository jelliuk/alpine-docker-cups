FROM alpine:latest
#
# BUILD:
#   docker build --rm --no-cache -t mycups .
#
# USAGE:
#   ./start_cups.sh
#

# Set metadata
LABEL author="thbe - https://github.com/thbe"
LABEL maintainer="jelliuk - https://github.com/jelliuk"
LABEL version="4.0"
LABEL description="Alpine CUPS print server with AirPrint/Avahi, Samsung ML-1910 and CLP-325 support"

# Set environment
ENV LANG=en_US.UTF-8
ENV TERM=xterm

# Set workdir
WORKDIR /opt/cups

# Install CUPS, Avahi, and driver dependencies in one layer
RUN apk update --no-cache && \
    apk add --no-cache \
      cups \
      cups-filters \
      avahi \
      inotify-tools \
      dbus \
      ghostscript

# Install Splix (ML-1910 / SPL mono driver) and build foo2zjs from source
# (foo2qpdl / QPDL colour driver for CLP-325 — not packaged in Alpine)
RUN apk add --no-cache \
      splix \
      --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
 && apk add --no-cache --virtual .build-deps \
      build-base \
      ghostscript \
      wget \
 && wget -q http://foo2zjs.rkkda.com/foo2zjs.tar.gz \
 && tar xzf foo2zjs.tar.gz \
 && cd foo2zjs \
 && make \
 && make install \
 && cd .. \
 && rm -rf foo2zjs foo2zjs.tar.gz \
 && apk del .build-deps

# Copy configuration files and PPDs, ensure scripts are executable
COPY --chmod=755 root /

# Expose IPP printer sharing
# Expose mDNS / Avahi advertisement
EXPOSE 631/tcp 5353/udp

# Health check — confirms CUPS is answering on IPP port
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD nc -z localhost 631 || exit 1

# Start CUPS instance
CMD ["/srv/run.sh"]