#! /bin/sh
#
# Launch the dockerized CUPS print server.
#
# Usage:
#   export CUPS_PASSWORD='MySeCret!'   # optional — defaults to "password"
#   export CUPS_DEBUG=1                # optional — enables verbose logging
#   ./start_cups.sh
#

### Default password guard (note: original script had the condition inverted) ###
if [ -z "${CUPS_PASSWORD}" ]; then
  CUPS_PASSWORD="password"
fi

### Resolve host FQDN ###
CUPS_HOST="$(hostname -f 2>/dev/null || hostname)"
CUPS_DOMAIN="$(echo "${CUPS_HOST}" | sed -e 's/^[^.]*\.//')"

docker run --detach --restart unless-stopped \
  --cap-add=SYS_ADMIN \
  -e CUPS_ENV_HOST="${CUPS_HOST}" \
  -e CUPS_ENV_PASSWORD="${CUPS_PASSWORD}" \
  -e CUPS_ENV_DEBUG="${CUPS_DEBUG}" \
  --name cups \
  --hostname "cups.${CUPS_DOMAIN}" \
  -p 631:631/tcp \
  -p 5353:5353/udp \
  -v cups-config:/etc/cups \
  mycups
