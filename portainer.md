# Docker & Portainer Setup (Debian/Ubuntu)

## 1. Prerequisites & System Update

Ensure the system is up to date and has basic tools installed:

```bash
apt update && apt upgrade -y
apt install -y ca-certificates curl gnupg lsb-release apt-transport-https
```

---

## 2. Docker Installation

### Add GPG Key
This step identifies the OS automatically and adds the correct key:

```bash
mkdir -p /etc/apt/keyrings
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')

curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

### Add Repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Install Docker Engine

```bash
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

---

## 3. Portainer Installation

### Create Persistent Volume

```bash
docker volume create portainer_data
```

### Deploy Portainer Container
Using Port 9443 for Web UI (HTTPS):

```bash
docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

---

## Access & Configuration

### Web Interface
1. Navigate to: `https://<VM_IP>:9443`
2. Create your admin password.
3. Select **"Get Started"** to manage the local environment.

### User Permissions (Optional)
If you create a non-root user later, add them to the docker group:
```bash
usermod -aG docker <your_username>
```

---

## Notes
- **Auto-start**: Docker and Portainer are configured with `restart: always` to survive VM reboots.