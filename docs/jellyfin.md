# Jellyfin for films and series

Jellyfin serves the films and series on the host data disk to the browser, the TV and phones. It gets its own unprivileged LXC like the other services; the media folder is bind-mounted read-only, so Jellyfin cannot damage the files.

Storage is split by disk:

| What | Where | Disk |
| --- | --- | --- |
| Jellyfin itself, config, database, posters, transcode cache | LXC rootfs on `local-lvm` (`/opt/homelab/jellyfin`) | SSD |
| Films and series | `/mnt/pve/data/media`, bind-mounted at `/mnt/media` | HDD |

The library database and the hundreds of small poster images make the UI feel slow on a spinning disk, and transcoding writes segments all the time; both belong on the SSD. Films are only read sequentially, which an HDD handles fine.

## 1. Media folder on the host

```bash
mkdir -p /mnt/pve/data/media/{movies,tv}
chown -R --reference=/mnt/pve/data /mnt/pve/data/media   # same owner as the rest of the disk
chmod -R 775 /mnt/pve/data/media
```

Jellyfin only needs to read, so ownership matches the rest of the data disk and whoever puts files there can write. The `smb` LXC already mounts the whole disk at `/data`, so the folder shows up in Samba and File Browser as `media` without another mount point.

## 2. Create the LXC

```bash
pveam download data debian-12-standard_<version>_amd64.tar.zst   # pveam available --section system
pct create 114 data:vztmpl/debian-12-standard_<version>_amd64.tar.zst \
  --hostname jellyfin --cores 2 --memory 1536 --swap 1024 \
  --rootfs local-lvm:16 --unprivileged 1 --features nesting=1,keyctl=1 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,ip=192.168.10.15/24,gw=192.168.10.1 \
  --mp0 /mnt/pve/data/media,mp=/mnt/media,ro=1 \
  --onboot 1 --ssh-public-keys ~/.ssh/authorized_keys
pct start 114
```

The rootfs holds the Jellyfin config, metadata and transcode cache; 16 GB is plenty for a home library. `local-lvm` is a thin pool on the 120 GB NVMe, so check `lvs pve/data` first: a thin pool that fills up corrupts every guest on it.

**Hardware transcoding.** Same as Immich: pass the iGPU render node, with the `render` group id from inside the LXC (`pct exec 114 -- getent group render`):

```bash
pct set 114 --dev0 /dev/dri/renderD128,gid=<render gid>
```

Then start the stack with `compose.vaapi.yml` as well (see [`stacks/jellyfin`](../stacks/jellyfin)). Without it Jellyfin still works, but a 1080p transcode will keep both CPU cores busy. Clients that can play the file directly (most TVs, Infuse, the Jellyfin apps) do not transcode at all.

## 3. Deploy

From `ansible/`, with `jellyfin` in the inventory:

```bash
ansible-playbook playbooks/site.yml --limit jellyfin
```

Open http://192.168.10.15:8096, create the admin user and add the libraries:

| Library | Content type | Folder |
| --- | --- | --- |
| Movies | Movies | `/media/movies` |
| Series | Shows | `/media/tv` |

## 4. Folder layout

Jellyfin matches files by name, so keep this layout:

```
tv/
  South Park (1997)/
    Season 01/
      South Park S01E01.mkv
      South Park S01E02.mkv
movies/
  South Park Bigger Longer & Uncut (1999)/
    South Park Bigger Longer & Uncut (1999).mkv
```

## 5. Several dubs in one file

An `.mkv` can carry several audio tracks; Jellyfin lists them all in the player's audio menu and switches without restarting the episode. Each user picks the default in *Profile → Playback → Preferred audio language*, and Jellyfin remembers the last track chosen within a series.

The preferred language only works if the tracks are tagged with a language. Check one file:

```bash
mkvmerge -J "South Park S01E01.mkv" | jq '.tracks[] | select(.type=="audio") | {id, lang: .properties.language, name: .properties.track_name}'
```

If a track shows `und` (undefined), tag it in place without remuxing (`a1`, `a2` are the first and second audio tracks). Do it before the files land in the media folder, the LXC mount is read-only:

```bash
for f in *.mkv; do
  mkvpropedit "$f" --edit track:a1 --set language=rus --edit track:a2 --set language=eng
done
```

After changing files, run *Dashboard → Libraries → Scan all libraries*.

## 6. Check

- Play an episode in the browser and on the TV, switch the audio track mid-episode.
- With VA-API on, start a transcode (pick a lower quality) and see `VAAPI` in *Dashboard → Activity*.
- In Grafana, the `jellyfin` probe is UP.
