FROM debian:trixie-slim

# trixie, NOT bookworm: `docker-cli` only exists in trixie (bookworm: "Unable to locate package")
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server docker-cli mariadb-client net-tools iputils-ping ca-certificates && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd && echo 'root:root' | chpasswd && sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config

# scripts/mgmt.sh is bind-mounted to /usr/local/bin/mgmt by compose (kept editable on the host)
EXPOSE 22
CMD ["sh", "-c", "/usr/sbin/sshd -D"]
