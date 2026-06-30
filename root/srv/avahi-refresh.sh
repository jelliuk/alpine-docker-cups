#! /bin/sh
#
# Watch /etc/cups for printers.conf changes and refresh the AirPrint
# Avahi service advertisements.
#

SRC_DIR=/etc/avahi/services.dist
DST_DIR=/etc/avahi/services

/usr/bin/inotifywait -m -e close_write,moved_to,create /etc/cups |
  while read -r directory events filename; do
    if [ "$filename" = "printers.conf" ]; then
      rm -f "${DST_DIR}"/AirPrint-*.service
      cp "${SRC_DIR}"/AirPrint-*.service "${DST_DIR}"/
    fi
  done
