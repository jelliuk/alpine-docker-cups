FROM debian:trixie-slim@sha256:b6e2a152f22a40ff69d92cb397223c906017e1391a73c952b588e51af8883bf8

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
LABEL description="Debian Trixie Slim CUPS print server with AirPrint/Avahi, Samsung ML-1910 and CLP-325 support"

# Set environment
ENV LANG=en_GB.UTF-8
ENV TERM=xterm

# Install CUPS, Avahi, driver dependencies, and netcat for health check
RUN apt-get update && apt-get install -y --no-install-recommends \
      cups \
      cups-filters \
      avahi-daemon \
      inotify-tools \
      ghostscript \
      curl \
      printer-driver-foo2zjs \
      printer-driver-splix \
 && rm -rf /var/lib/apt/lists/*

# Copy configuration files and PPDs
COPY root /

# Ensure only scripts are executable
RUN chmod 755 /srv/run.sh

# Expose IPP printer sharing and mDNS / Avahi advertisement
EXPOSE 631/tcp 5353/udp

# Health check — confirms CUPS is answering on IPP port
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl --fail --silent --output /dev/null \
       --unix-socket /run/cups/cups.sock \
       http://localhost/printers/ || exit 1

# Start CUPS instance
CMD ["/srv/run.sh"]
