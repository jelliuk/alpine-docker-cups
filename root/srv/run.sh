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
#   v4.0 - Remove avahi-refresh.sh the printers are statically defined
#           at container build, this is needlessly complex.
#   v4.1 - Honour PUID/PGID: create a matching user/group and re-own the
#           bind-mounted CUPS directories so files written at runtime
#           are accessible from the host under the requested identity.
#           cupsd itself continues to run as root (it needs raw device
#           access to the USB printers and privileged startup), so this
#           only affects on-disk ownership of config/spool/log data.
#

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

### PUID/PGID ###
#
# No enforced default here (unlike the password): 1000:1000 is a
# reasonable, well-known fallback for "first host user" and getting
# this wrong just means wrong file ownership on the bind mounts, not
# an open admin panel — so it's fine to default rather than hard-fail.
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if ! printf '%s' "${PUID}" | grep -qE '^[0-9]+$' || \
   ! printf '%s' "${PGID}" | grep -qE '^[0-9]+$'; then
  RETURN=1; REASON="PUID/PGID must be numeric — aborting!"; exit
fi

# Reuse an existing group/user with that id if one already exists
# (e.g. it collides with a package-created system account), otherwise
# create a dedicated one.
CUPS_GROUP="$(getent group "${PGID}" | cut -d: -f1)"
if [ -z "${CUPS_GROUP}" ]; then
  groupadd -g "${PGID}" cupsdata
  CUPS_GROUP="cupsdata"
fi

CUPS_USER="$(getent passwd "${PUID}" | cut -d: -f1)"
if [ -z "${CUPS_USER}" ]; then
  useradd -u "${PUID}" -g "${CUPS_GROUP}" -M -s /usr/sbin/nologin cupsdata
  CUPS_USER="cupsdata"
fi

echo "Aligning CUPS data directories to PUID=${PUID} (${CUPS_USER}) PGID=${PGID} (${CUPS_GROUP})"

# Re-own only the directories that are actually bind-mounted per the
# Dockerfile (/etc/cups) plus CUPS' own runtime data dirs. Do NOT
# touch /usr/share/cups/model or other image-baked, read-only content.
for d in /etc/cups /var/spool/cups /var/cache/cups /var/log/cups; do
  if [ -d "${d}" ]; then
    chown -R "${PUID}:${PGID}" "${d}" || {
      RETURN=$?; REASON="Failed to chown ${d} to ${PUID}:${PGID} — aborting!"; exit
    }
  fi
done

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
  Data dirs owned by: ${PUID}:${PGID} (${CUPS_USER}:${CUPS_GROUP})
  Printers configured:
    - Samsung ML-1910  (USB / mono laser)
    - Samsung CLP-325  (USB / colour laser)

  NOTE: Browsing, discovery and the admin UI are reachable by
  anyone who can reach port 631. This image is intended for a
  trusted LAN only — do not forward port 631 to the internet.
===========================================================
EOF

### Start Avahi ###
# Note: run in the foreground as a backgrounded shell job to ensure logs are captured, rather than daemonize (docker logs would otherwise only show the parent's stale-PID cleanup, not avahi's own runtime output)
/usr/sbin/avahi-daemon &

### Start CUPS (foreground so Docker tracks the process correctly) ###
exec /usr/sbin/cupsd -f -c /etc/cups/cupsd.conf
