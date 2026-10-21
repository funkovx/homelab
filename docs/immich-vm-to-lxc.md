# Moving Immich from a VM to an LXC

> **Done on 2026-10-21.** Immich runs in LXC 113 (192.168.10.13). VM 102 is shut down and kept for a rollback until early November. The database came from Immich's own nightly backup instead of a fresh dump, see [Restoring from the nightly backup](#restoring-from-the-nightly-backup).

Immich used to run in a 4 GB Ubuntu VM next to Portainer and an old Beszel hub. On a mini PC with 10 GB of RAM a whole guest OS for a few containers is expensive, so it moved into an unprivileged LXC. The photo library never moves: it already lives on the host data disk (`/mnt/pve/data/immich`), the VM saw it over VirtIO-FS and the LXC sees it as a bind mount. Only the database is carried over.

Downtime is the time it takes to dump and restore the database, about 10 minutes.

## 0. Before you start

On the VM, write down what is running:

```bash
sudo docker image inspect ghcr.io/immich-app/immich-server:release \
  --format '{{index .Config.Labels "org.opencontainers.image.version"}}'   # v2.6.3
sudo docker inspect immich_server --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
```

The new install must use **the same Immich version** and mount the library at **the same path inside the container** (`/usr/src/app/upload`), because the database stores absolute file paths.

Back up the VM so the old setup can be restored in one step:

```bash
vzdump 102 --mode snapshot --storage data --compress zstd
```

## 1. Create the LXC

```bash
pveam update && pveam available --section system | grep debian-12
pveam download data debian-12-standard_<version>_amd64.tar.zst

pct create 113 data:vztmpl/debian-12-standard_<version>_amd64.tar.zst \
  --hostname immich --cores 4 --memory 4096 --swap 1024 \
  --rootfs local-lvm:16 --unprivileged 1 --features nesting=1,keyctl=1 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,ip=192.168.10.13/24,gw=192.168.10.1 \
  --mp0 /mnt/pve/data/immich,mp=/mnt/immich \
  --onboot 1 --ssh-public-keys ~/.ssh/authorized_keys
pct start 113
```

`nesting` and `keyctl` let Docker run inside an unprivileged container.

**Permissions.** In an unprivileged LXC, root inside the container is UID 100000 on the host. Immich writes as root, so the library has to belong to 100000:

```bash
chown -R 100000:100000 /mnt/pve/data/immich
```

**Optional: hardware transcoding.** The Ryzen 5 PRO 2400GE has a Vega iGPU that handles VA-API. Pass the render node into the container; the `gid` must be the `render` group inside the LXC (`pct exec 113 -- getent group render`):

```bash
pct set 113 --dev0 /dev/dri/renderD128,gid=<render gid>
```

Then start Immich with `compose.vaapi.yml` as well (see [`stacks/immich`](../stacks/immich)).

## 2. Install Docker and prepare Immich

From `ansible/`, with `immich` added to the inventory:

```bash
ansible-playbook playbooks/site.yml --limit immich
```

This installs Docker, node-exporter and Alloy, and copies `stacks/immich` to `/opt/homelab/immich`. Create `.env` there from `.env.example` with the **same** `DB_PASSWORD` as on the VM, then create the containers without starting them:

```bash
cd /opt/homelab/immich && docker compose create
```

## 3. Switch over

On the VM, stop everything except the database and dump it:

```bash
sudo docker stop immich_server immich_machine_learning
sudo docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=postgres \
  | gzip > immich-db.sql.gz
sudo docker stop immich_postgres
```

Copy `immich-db.sql.gz` to the LXC, then restore it into a fresh database:

```bash
docker start immich_postgres && sleep 10
gunzip --stdout immich-db.sql.gz \
  | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
  | docker exec -i immich_postgres psql --dbname=postgres --username=postgres
docker compose up -d
```

### Restoring from the nightly backup

Immich dumps its database every night to `backups/` inside the library, so with the VM already off a fresh dump is not needed. The nightly file is a `pg_dump` of the `immich` database only (no roles), so the new `DB_PASSWORD` does not have to match the old one; restore it into `immich`, not `postgres`. Anything uploaded after the dump time is not in it.

```bash
cd /opt/homelab/immich
docker compose -f compose.yml -f compose.vaapi.yml down
rm -rf ./postgres                       # only the empty database from the first start
docker compose -f compose.yml -f compose.vaapi.yml create
docker start immich_postgres && sleep 10
gunzip --stdout /mnt/immich/backups/immich-db-backup-<date>-v2.6.3-pg14.19.sql.gz \
  | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
  | docker exec -i immich_postgres psql -v ON_ERROR_STOP=1 --dbname=immich --username=postgres
docker compose -f compose.yml -f compose.vaapi.yml up -d
```

## 4. Point traffic at the new address

- **Clients:** devices reach Immich over Tailscale, so change the server URL in the mobile apps to `http://192.168.10.13:2283`.
- **Glance and Prometheus:** done in this repository (`stacks/glance/glance.yml`, `stacks/monitoring/prometheus/prometheus.yml`).

## 5. Check

- Log in on the web and in the mobile app, open a few old photos and videos.
- Upload a photo from the phone and make sure it appears.
- Search by text ("cat", "beach"): this confirms the machine learning container works.
- In Grafana, the `immich` probe is UP and the LXC stays within its memory limit.

## 6. Clean up

Keep VM 102 shut down for a week or two. If something is wrong, stop the LXC, `chown -R 1000:1000 /mnt/pve/data/immich` and start the VM again. Once everything is fine, remove the VM and its backup:

```bash
qm destroy 102 --purge
```
