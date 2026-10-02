FROM nginx:alpine

# keepalived does VRRP-only here (VIP failover). No LVS => the ip_vs kernel module is
# NOT required, which matters because WSL2 kernels usually lack it.
RUN apk add --no-cache keepalived bash

COPY nginx.conf /etc/nginx/nginx.conf
COPY keepalived/ /etc/keepalived/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080 443 2222 2223 2224
ENTRYPOINT ["/entrypoint.sh"]
