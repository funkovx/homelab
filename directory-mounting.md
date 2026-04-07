# LXC Directory Mount Guide (Proxmox)

## 1. Host Preparation
Identify the directory on the Proxmox host. For **Unprivileged** containers, UID/GID are mapped by adding 100000.
* **Internal root (0)** = 100000 on host.
* **Internal user (1000)** = 101000 on host.

Run on the Proxmox host:
```bash
chown -R 101000:101000 /mnt/pve/your_data
chmod -R 775 /mnt/pve/your_data
```

## 2. Add Mount Point
Run on the Proxmox host (replace `XXX` with your Container ID):
```bash
pct set XXX -mp0 /mnt/pve/your_data,mp=/data
```
* `mp0`: Mount point identifier.
* `/data`: Destination path inside the container.

## 3. Container Verification
Check permissions inside the LXC:
```bash
ls -la /data
```
