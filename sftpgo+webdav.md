# SFTPGo + WebDAV Setup

## 1. Prerequisites

Ensure dependencies are installed:

```bash
apt update && apt install -y debian-archive-keyring gnupg apt-transport-https curl wget
```

---

## 2. Installation

```bash
wget https://github.com/drakkan/sftpgo/releases/download/v2.7.1/sftpgo_2.7.1-1_amd64.deb
dpkg -i sftpgo_2.7.1-1_amd64.deb
apt install -f -y
rm sftpgo_2.7.1-1_amd64.deb
```

---

## 3. WebDAV Configuration (for example port 7777)

1. **Edit the config file:**
```bash
nano /etc/sftpgo/sftpgo.json
```

2. **Enable WebDAV:**
Search for `"webdavd"` and change the port to your custom **7777**:
```json
"webdavd": {
 "bindings": [
   {
     "port": 7777,
     "address": "",
     "enable_https": false
   }
 ],
 "enabled": true
}
```

3. **Restart and Verify:**
```bash
systemctl restart sftpgo
ss -tulpn | grep 7777
```

---

## 4. Permission Fix (The "Sftpgo" User)

SFTPGo runs under its own user. To avoid `Permission Denied` when writing to `/data` or `/mnt` grant ownership to the sftpgo user:

```bash
chown -R sftpgo:sftpgo /data
chmod -R 755 /data
```

## Notes
- **WebAdmin:** `http://<IP>:8080/web/admin` — here you create users.
- **WebClient:** `http://<IP>:8080` — the UI from your screenshot.
- **WebDAV:** `http://<IP>:10080` — for network drive mapping.

---

## If you have troubles with access

```bash
id sftpgo
```

This is a key point for working with Unprivileged LXC or VM, where the service inside the container needs to actually write files to the host's physical disk.

Once you know the user ID inside the container (for example, `id sftpgo` returned 1000), you need to "befriend" it with the folder on the host.

1. Determine the real UID on the host  
   In unprivileged Proxmox containers, 100000 is added to the internal ID.  
   Internal root (0) = 100000 on the host.  
   Internal sftpgo (1000) = 101000 on the host.

2. Apply permissions on the host  
    Run this command in the Proxmox terminal itself so that unprivileged SFTPGo container can create folders and upload files via WebDAV.

```bash
chown -R 101000:101000 /mnt/pve/your_data_path
chmod -R 775 /mnt/pve/your_data_path
```
