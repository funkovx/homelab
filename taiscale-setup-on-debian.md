# Tailscale Setup on Debian

## Prerequisites: Proxmox Configuration

### 1. Edit LXC Container Configuration

Replace `XXX` with your container ID:

```bash
nano /etc/pve/lxc/XXX.conf
```

Add the following lines to the end of the file:

```bash
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
lxc.cap.drop:
```

### 2. Set Permissions

```bash
chown 100000:100000 /dev/net/tun
```

---

## Network Configuration

### Enable IP Forwarding

```bash
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
```

### Configure DNS and Firewall

```bash
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
apt update && apt install -y iptables iptables-persistent
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
netfilter-persistent save
```

### Optimize UDP Forwarding

```bash
ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list on 2>/dev/null
```

---

## Tailscale Installation

### Add Tailscale's GPG Key

```bash
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | 
  tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
```

### Add Tailscale Repository

```bash
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | 
  tee /etc/apt/sources.list.d/tailscale.list
```

### Install Tailscale

```bash
apt-get update && apt-get install -y tailscale
```

---

## Running Tailscale

### Basic Setup

```bash
tailscale up
```

### Reset Tailscale Daemon (if needed)

```bash
systemctl stop tailscaled
pkill -9 tailscaled
rm -rf /var/run/tailscale/tailscaled.sock
```

### Configure as Exit Node with Local Network Routes

Replace `192.168.10.0/24` with your actual local network subnet:

```bash
tailscale up --advertise-routes=192.168.10.0/24 --advertise-exit-node --reset
```

---

## Notes

- Ensure you have admin access to run these commands with `sudo`
- Configure exit node routes in Tailscale console for access control
- Use `tailscale status` to verify connection status
- For troubleshooting, check logs with: `journalctl -u tailscaled`