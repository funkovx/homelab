# Nginx Proxy Manager (NPM) Setup with VPS & Tailscale Tunnel

Technical documentation for exposing a home-lab behind a CGNAT (Gray IP) using a public VPS as a gateway.

## Nginx Proxy Manager Installation (LXC/Docker)

### Install Docker & Docker Compose

If not already installed in your container:

```bash
apt update && apt install -y curl
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### Create Project Directory

```bash
mkdir -p ~/npm && cd ~/npm
nano docker-compose.yml
```

### Docker Compose Configuration

Paste the following configuration:

```yaml
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: always
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
```

### Deploy NPM

```bash
docker compose up -d
```

## Prerequisites: VPS Preparation (Gateway)

### 1. Enable IP Forwarding

The VPS must be allowed to route traffic between the public interface and the Tailscale tunnel.

```bash
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
```

### 2. Configure Network Address Translation (iptables)

Map public ports 80/443 to the NPM Tailscale IP (Replace `xxx.xxx.xxx.xxx` with your NPM's Tailscale IP).

```bash
apt update && apt install -y iptables-persistent

# Forward HTTP and HTTPS traffic
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination xxx.xxx.xxx.xxx:80
iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination xxx.xxx.xxx.xxx:443

# Enable Masquerading for return traffic
iptables -t nat -A POSTROUTING -j MASQUERADE

# OPTIONAL: Optimize MTU for Tunnels
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Persist rules after reboot
netfilter-persistent save
```

---

## Configuration (NPM in LXC Container)

### 1. Proxmox LXC Tuning

If NPM is in an LXC container, you must allow TUN device access for Tailscale. Run this on the **Proxmox Host** (Replace `XXX` with your CT ID):

```bash
nano /etc/pve/lxc/XXX.conf
```

Add to the end:

```bash
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

Restart the container after saving.

---

## Nginx Proxy Manager Service Configuration

### General Proxy Host Setup

For standard services (Grafana, Beszel, etc.):

- **Domain Names:** `service.yourdomain.com`
- **Scheme:** `http`
- **Forward IP:** Internal LAN IP (e.g., `192.168.10.5`)
- **Forward Port:** Service Port
- **Websockets Support:** **ON** (Required for Proxmox, Portainer, Immich)
### Proxmox Web UI Specifics

- **Scheme:** `https` (Proxmox uses SSL on 8006 by default)
- **Forward Port:** `8006`
- **SSL Tab:** Request New Certificate

### WebDAV / Large File Optimization (Advanced Tab)

To prevent timeouts and "Bad Gateway" errors during file transfers, add this to the Advanced section:

```
client_max_body_size 0;
proxy_buffering off;
proxy_request_buffering off;
proxy_set_header Destination $http_destination;
proxy_read_timeout 3600;
sendfile on;
tcp_nopush on;
```

But it does't help much, idk why. Maybe because I have slow vps.

---

## Notes

### Troubleshooting Commands

```bash
# Verify NPM is listening on port 81 (Admin UI)
ss -tulnp | grep :81

# Test if VPS can reach NPM through the tunnel
curl -I http://xxx.xxx.xxx.xxx:81
```

### Additional notes
- **DNS:** Point your Domain's A-Record to the Public IP of your VPS.
- **SSL:** Let's Encrypt certificates are generated on the home NPM. Ensure port 80 is correctly forwarded from the VPS for the ACME challenge to pass.
- **SSL:** If you want to use subdomains, request certificat for each one.
