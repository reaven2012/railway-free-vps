FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server \
      sudo \
      curl \
      ca-certificates \
      iproute2 \
      iputils-ping \
      python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Tailscale (will run in userspace-networking mode: no /dev/net/tun needed)
RUN curl -fsSL https://tailscale.com/install.sh | sh

# Regular user for SSH
RUN useradd -m -s /bin/bash ubuntu \
    && usermod -aG sudo ubuntu \
    && echo "ubuntu:changeme" | chpasswd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
