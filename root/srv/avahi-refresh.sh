#! /bin/sh

/usr/bin/inotifywait -m -e close_write,moved_to,create /etc/cups |
  while read -r directory events filename; do
    if [ "$filename" = "printers.conf" ]; then
      rm -rf /etc/avahi/services/AirPrint-*.service
      cp -r /etc/avahi/services/. /etc/avahi/services/
    fi
  done