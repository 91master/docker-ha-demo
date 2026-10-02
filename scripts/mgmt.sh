#!/usr/bin/env bash
# Management helper, runs inside the `admin` container (docker.sock mounted).
# Subcommands: ls | st | net | users | logins | db "<sql>"
set -uo pipefail

sql() { docker exec mariadb mariadb -ulogger -plogger123 lb_logs -e "$1" 2>/dev/null; }

case "${1:-ls}" in
  ls)      docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' ;;
  st)      docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' ;;
  net)     for c in nginx-lb nginx-lb2 web1 web2 admin redis mariadb; do
             ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$c")
             printf '  %-10s %s\n' "$c" "$ip"
           done ;;
  users)   sql 'SELECT id, username, created_at, last_seen FROM users ORDER BY id DESC LIMIT 20;' ;;
  logins)  sql 'SELECT backend, COUNT(*) AS logins FROM login_logs GROUP BY backend ORDER BY logins DESC;' ;;
  db)      sql "${2:?usage: mgmt db \"<sql>\"}" ;;
  *)       echo "usage: mgmt [ls|st|net|users|logins|db \"<sql>\"]" ;;
esac
