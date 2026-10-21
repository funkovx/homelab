# Mounting VirtIO-FS in Proxmox

### 1. Preparation on the Proxmox Host (Creating a Mapping)

First, you need to declare a folder at the datacenter level so that Proxmox can safely share it with virtual machines.

1. Ensure the folder physically exists on the server (if not, create it in the host terminal: `mkdir -p /mnt/pve/data/example_directory`).
2. In the Proxmox web interface, select **Datacenter** (the top level on the left).
3. Navigate to Directory Mappings.
4. Click **Add**:
    - **ID:** Choose a name (for example, `example_directory_share_map`).
    - **Path:** Specify the real path on the host (for example, `/mnt/pve/data/example_directory`).
    - Select the required node (Node) where the folder is located.

---

### 2. Virtual Machine Configuration (In the Proxmox Panel)

The VM must be **shut down**. Now you need to connect the created mapping to a specific VM.

1. **Enable NUMA (Required):**
    - Select your VM → **Hardware** → **Processors** → **Edit**.
    - Check the **NUMA: Yes** option (this will add `numa: 1` to the config).

2. **Add VirtIO-FS:**
    - In the **Hardware** section, click **Add** → **Virtio FS**.
    - **Directory:** Select the created mapping (`example_directory_share_map`).
    - **Tag:** Assign a disk name for the guest OS (for example, **`example_directory_data`**). Note: the tag can be omitted, in which case the mapping name will be used.

---

### 3. Mounting Inside the VM (Linux)

Connect to the virtual machine console.

1. **Create a mount point:**

```bash
sudo mkdir -p /mnt/example_directory
```

2. **Configure automatic mounting:**

Open the configuration file:

```bash
sudo nano /etc/fstab
```

Add a line at the end (the first word is the **Tag** or mapping name):

```
example_directory_share_map  /mnt/example_directory  virtiofs  defaults  0  0
```

3. **Apply the mounting:**

```bash
sudo mount -a
```

---

### 4. Configuring Access Permissions (In the Proxmox Host Terminal)

By default, the shared folder belongs to `root`. To allow Docker containers inside the VM (running as a regular user) to access it, you need to change permissions.

Run these commands **in the Proxmox console**:

```bash
chown -R 1000:1000 /mnt/pve/data/example_directory
chmod -R 775 /mnt/pve/data/example_directory
```

---

### Troubleshooting a Potential Issue

The command `ls -ln /mnt/example_directory` inside the VM returns `total 0` (the folder appears empty, even though files exist on the host).

**Causes and Solutions:**

1. **NUMA was not applied:** Shut down the VM via Shutdown and restart it.
2. **Typo in fstab:** Make sure the word `example_directory_data` in the `/etc/fstab` file matches exactly (character by character) with the **Tag** field in the Proxmox settings.