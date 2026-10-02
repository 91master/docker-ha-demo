#!/bin/sh
# One container runs BOTH keepalived (VIP) and nginx (traffic).
set -e

case "${KEEPALIVED_MODE:-preempt}" in
  backup)    CONF=/etc/keepalived/backup.conf ;;
  nopreempt) CONF=/etc/keepalived/master-nopreempt.conf ;;
  *)         CONF=/etc/keepalived/master-preempt.conf ;;
esac

echo "[entrypoint] keepalived mode=${KEEPALIVED_MODE:-preempt} conf=$CONF"
cp "$CONF" /etc/keepalived/keepalived.conf

# -n = log to stdout/journal, no fork
keepalived -n -f /etc/keepalived/keepalived.conf &
sleep 1

echo "[entrypoint] starting nginx in foreground"
exec nginx -g 'daemon off;'
