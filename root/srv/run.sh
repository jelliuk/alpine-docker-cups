#! /bin/sh
#
# Start CUPS and Avahi inside the container.
#
# Release: v3.1
#
# ChangeLog:
#   v0.1 - Initial release
#   v1.2 - First production ready release
#   v1.3 - Add Avahi
#   v2.0 - Auto-register Samsung ML-1910 and CLP-325; improved security;
#           remove SMB port exposure; honour CUPS_ADMIN_USER/GROUP vars
#   v3.0 - Debian Trixie Slim base; remove syslogd (not present in slim
#           image, Docker captures stdout/stderr directly); drop redundant
#           --syslog flag from avahi-daemon (implied by --daemonize)
#   v3.1 - Refuse to start with the default/blank CUPS password instead
#           of silently falling back to it; actually launch
#           avahi-refresh.sh in the background (previously written but
#           never started); avahi-refresh.sh now restores AirPrint
#           service files from a pristine copy instead of deleting them
#           and copying a now-empty directory onto itself.

### Enable debug if requested ###
if [ -n "${CUPS_ENV_DEBUG}" ]; then
  set -ex
fi

### Error handling ###
error_handling() {
  if [ "${RETURN}" -eq 0 ]; then
    echo "${SCRIPT} successful!"
  else
    echo "${SCRIPT} aborted — ${REASON}"
  fi
  exit "${RETURN}"
}
trap "error_handling" EXIT HUP INT QUIT TERM
RETURN=0
REASON="Finished!"

### Defaults ###
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export LC_ALL=C
export LANG=C
SCRIPT=$(basename "${0}")

### Sanity checks ###
if [ ! -f /.dockerenv ]; then
  RETURN=1; REASON="Not running inside Docker — aborting!"; exit
fi

### Password ###
#
# No default password. A print server's admin UI is reachable on the LAN
# by design (mDNS/AirPrint advertisement), so shipping a guessable
# default like "password" is a real exposure if anyone forwards 631
# externally or runs on an untrusted network. Require the operator to
# set one explicitly.
if [ -z "${CUPS_ENV_PASSWORD}" ]; then
  RETURN=1; REASON="CUPS_ENV_PASSWORD is not set — refusing to start with no admin password. Set -e CUPS_ENV_PASSWORD=<your password> and retry."; exit
fi
CUPS_PASSWORD="${CUPS_ENV_PASSWORD}"

if printf '%s' "${CUPS_PASSWORD}" | LC_ALL=C grep -q '[^ -~]\+'; then
  RETURN=1; REASON="CUPS password contains non-ASCII characters — aborting!"; exit
fi

### Set root password (used as the CUPS admin) ###
echo "root:${CUPS_PASSWORD}" | /usr/sbin/chpasswd
if [ $? -ne 0 ]; then
  RETURN=$?; REASON="Failed to set root password — aborting!"; exit
fi

### Configure Avahi ###
sed -i 's/.*enable-dbus=.*/enable-dbus=no/'             /etc/avahi/avahi-daemon.conf
sed -i 's/.*enable-reflector=.*/enable-reflector=yes/'  /etc/avahi/avahi-daemon.conf
sed -i 's/.*reflect-ipv=.*/reflect-ipv=yes/'            /etc/avahi/avahi-daemon.conf

cat <<EOF
===========================================================
  CUPS Print Server is ready!
  URL:      https://${CUPS_ENV_HOST:-localhost}:631/
  Username: root
  Password: ${CUPS_PASSWORD}
  Printers configured:
    - Samsung ML-1910  (USB / mono laser)
    - Samsung CLP-325  (USB / colour laser)

  NOTE: Browsing, discovery and the admin UI are reachable by
  anyone who can reach port 631. This image is intended for a
  trusted LAN only — do not forward port 631 to the internet.
===========================================================
EOF

### Start Avahi ###
# Note: --daemonize implies --syslog; logs captured by Docker via stderr
/usr/sbin/avahi-daemon --daemonize

### Watch /etc/cups for printers.conf changes and refresh AirPrint
### service advertisements accordingly. Backgrounded — it runs for the
### lifetime of the container alongside cupsd.
/srv/avahi-refresh.sh &

### Wait for Avahi to be ready, then start CUPS ###
sleep 1

### Start CUPS (foreground so Docker tracks the process correctly) ###
exec /usr/sbin/cupsd -f -c /etc/cups/cupsd.conf
