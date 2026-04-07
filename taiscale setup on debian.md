# На хосте proxmox

ХХХ заменить на айди контейнера
```bash
nano /etc/pve/lxc/XXX.conf
```

Вставить в конец файла
```bash
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
lxc.cap.drop:
```

```bash
chown 100000:100000 /dev/net/tun
```

# Включаем IP Forwarding

```bash
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
```

# Add nameserver + update

```bash
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
apt update && apt install -y iptables iptables-persistent
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
netfilter-persistent save
```

# UDP настройка

```bash
ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list on 2>/dev/null
```

# Add Tailscale's GPG key

```bash
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
```

# Add the tailscale repository

```bash
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
```

# Install Tailscale

```bash
apt-get update && apt-get install tailscale
```

# Start Tailscale!

```bash
tailscale up
```

```bash
systemctl stop tailscaled
pkill -9 tailscaled
rm -rf /var/run/tailscale/tailscaled.sock
```

Start tailscale as exit node for local network

```bash
tailscale up --advertise-routes=192.168.10.0/24 --advertise-exit-node --reset
```
