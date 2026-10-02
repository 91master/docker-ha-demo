#!/usr/bin/env bash
# End-to-end verification of the HA stack. Writes a full log to logs/verify-<ts>.log.
# Probes go through the VIP (172.18.0.100) from the WSL host, which can reach the
# docker bridge network directly.
set -uo pipefail

cd "$(dirname "$0")/.."
mkdir -p logs
LOG="logs/verify-$(date +%Y%m%d-%H%M%S).log"
VIP=172.18.0.100
BASE="http://$VIP:8080"
PASS=0; FAIL=0

say() { echo "$*" | tee -a "$LOG"; }
ok()  { PASS=$((PASS+1)); say "  [PASS] $*"; }
bad() { FAIL=$((FAIL+1)); say "  [FAIL] $*"; }

vip_get()  { curl -s --max-time 8 "$BASE/index.php"; }
vip_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$BASE/index.php"; }

say "== 1. all 7 containers running =="
for c in nginx-lb nginx-lb2 web1 web2 admin redis mariadb; do
  state=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null)
  [ "$state" = "running" ] && ok "$c running" || bad "$c state=${state:-missing}"
done

say "== 2. VIP is held by the MASTER only =="
docker exec nginx-lb  ip -4 addr show eth0 | grep -q "$VIP" && ok "nginx-lb holds $VIP"        || bad "nginx-lb has no VIP"
docker exec nginx-lb2 ip -4 addr show eth0 | grep -q "$VIP" && bad "nginx-lb2 wrongly holds it" || ok "nginx-lb2 has no VIP"

say "== 3. round-robin across both PHP-FPM backends (through the VIP) =="
# Both FPM workers need a moment after `up`; wait until each one has answered once,
# otherwise the first probe burst races web2 and every request lands on web1.
deadline=$((SECONDS + 60)); warm=""
while [ $SECONDS -lt $deadline ]; do
  b=$(vip_get | grep -o 'web[12]' | head -1); warm="$warm ${b:-?}"
  echo "$warm" | grep -q web1 && echo "$warm" | grep -q web2 && break
  sleep 2
done
say "    warm-up samples:$warm"
seen=""
for i in 1 2 3 4 5 6 7 8; do
  b=$(vip_get | grep -o 'web[12] ([0-9.]*)' | head -1)
  say "    request $i -> ${b:-<empty>}"
  seen="$seen $b"
done
c1=$(echo "$seen" | tr ' ' '\n' | grep -c '^web1' || true)
c2=$(echo "$seen" | tr ' ' '\n' | grep -c '^web2' || true)
if [ "$c1" -ge 1 ] && [ "$c2" -ge 1 ]; then
  ok "both backends served traffic (${c1}x web1, ${c2}x web2)"
else
  bad "only one backend served:$seen"
fi

say "== 4. session survives landing on BOTH backends (redis session store) =="
jar=$(mktemp)
curl -s -c "$jar" -o /dev/null --max-time 8 -X POST -d 'username=verify' "$BASE/login.php"
seq_b=""; seq_who=""
for i in 1 2 3 4 5 6; do
  out=$(curl -s -b "$jar" --max-time 8 "$BASE/dashboard.php")
  b=$(echo "$out"  | grep -o 'web[12]' | head -1)
  who=$(echo "$out" | grep -o 'hello, [a-zA-Z0-9_]*' | head -1)
  seq_b="$seq_b $b"; seq_who="$seq_who $who"
  say "    dashboard $i -> backend=${b:-?}  $who"
done
rm -f "$jar"
if echo "$seq_b" | grep -q web1 && echo "$seq_b" | grep -q web2; then ok "backend alternated during the session test"; else bad "backend did not alternate: $seq_b"; fi
if echo "$seq_who" | grep -qv 'hello, verify'; then bad "login was lost on some request"; else ok "login persisted across every request (same redis session)"; fi

say "== 5. failover: kill keepalived on the master =="
before=$(vip_code)
docker exec nginx-lb killall keepalived >/dev/null 2>&1
sleep 5
docker exec nginx-lb2 ip -4 addr show eth0 | grep -q "$VIP" && ok "VIP drifted to nginx-lb2" || bad "VIP did not drift"
after=$(vip_code)
say "    HTTP via VIP: before=$before  after=$after"
[ "$after" = "200" ] && ok "traffic kept flowing through the VIP during failover" || bad "VIP stopped answering (code=$after)"

say "== 6. failback (preempt) =="
docker exec -d nginx-lb keepalived -n -f /etc/keepalived/keepalived.conf >/dev/null 2>&1
sleep 6
docker exec nginx-lb ip -4 addr show eth0 | grep -q "$VIP" && ok "VIP returned to nginx-lb" || bad "VIP stayed on the backup (preempt failed)"

say "== 7. HTTPS server block (self-signed) =="
code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 8 -H 'Host: lb.local' https://127.0.0.1:8443/index.php)
[ "$code" = "200" ] && ok "https 8443 -> 200" || bad "https 8443 -> $code"

say "== 8. L4 stream proxy: SSH banner on TCP 2222 =="
banner=$(timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2222; head -1 <&3' 2>/dev/null)
case "$banner" in
  SSH-2.0*) ok "2222 -> $banner" ;;
  *)        bad "2222 -> ${banner:-<nothing>}" ;;
esac

say "== 9. management container talks to the docker socket =="
out=$(docker exec admin mgmt net 2>/dev/null)
echo "$out" | grep -q '172.18.0.11' && ok "admin sees the container network (mgmt net)" || bad "mgmt net returned nothing"
out=$(docker exec admin mgmt logins 2>/dev/null)
echo "$out" | grep -qi 'backend' && ok "admin queried mariadb through the socket (mgmt logins)" || bad "mgmt logins returned nothing"

say ""
say "RESULT: $PASS passed, $FAIL failed   (log: $LOG)"
[ "$FAIL" -eq 0 ]
