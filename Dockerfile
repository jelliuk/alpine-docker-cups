FROM debian:trixie-slim@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2

# Set metadata
LABEL author="thbe - https://github.com/thbe, jelliuk <https://github.com/jelliuk>"  \
      maintainer="jelliuk - https://github.com/jelliuk" \
      version="4.0" \
      description="Debian Trixie Slim CUPS print server with AirPrint/Avahi, Samsung ML-1910 and CLP-325 support" \
      org.opencontainers.image.title="docker-cups" \
      org.opencontainers.image.description="Debian Trixie Slim CUPS print server with AirPrint/Avahi, Samsung ML-1910 and CLP-325 support" \
      org.opencontainers.image.authors="thbe <https://github.com/thbe>, jelliuk <https://github.com/jelliuk>" \
      org.opencontainers.image.source="https://github.com/jelliuk/docker-cups" \
      org.opencontainers.image.version="4.0" \
      org.opencontainers.image.licenses="MIT"

# Set environment
ENV LANG=en_GB.UTF-8
ENV TERM=xterm

# Install CUPS, Avahi, driver dependencies, and netcat for health check
RUN apt-get update && apt-get install -y --no-install-recommends \
      cups \
      cups-filters \
      avahi-daemon \
      ghostscript \
      curl \
      printer-driver-foo2zjs \
      printer-driver-splix \
 && rm -rf /var/lib/apt/lists/* \
 && apt-get clean

# Detailed Specific Copy for configuration files and PPDs
COPY root/etc/cups               /etc/cups
COPY root/etc/avahi/services      /etc/avahi/services
COPY root/usr/share/cups/model    /usr/share/cups/model
COPY root/srv                     /srv

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
