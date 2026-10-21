# Ansible

Configuration of the Proxmox host and every LXC, and deployment of the Docker stacks.

| Role | Hosts | Does |
| --- | --- | --- |
| `base` | all | Base packages, timezone, automatic security updates, optional SSH hardening |
| `node_exporter` | all | `prometheus-node-exporter` on :9100 for Prometheus |
| `docker` | `docker_hosts` | Docker Engine and the Compose plugin from the official repository |
| `alloy` | `log_shippers` | Grafana Alloy: systemd journal and Docker logs to Loki |

`playbooks/deploy-stacks.yml` copies the projects listed in each host's `compose_projects` from `stacks/` to `/opt/homelab/` and runs `docker compose up` for each. Override files such as `compose.vaapi.yml` go in `compose_files`, per stack:

```yaml
jellyfin:
  ansible_host: 192.168.10.15
  compose_projects: [jellyfin]
  compose_files: {jellyfin: [compose.yml, compose.vaapi.yml]}
```

Alloy runs only where it is worth its memory: the host and the guests with Docker. The small single-service containers (Pi-hole, Navidrome, Samba, Tailscale) are covered by node-exporter metrics and HTTP probes.

```bash
ansible-galaxy collection install -r requirements.yml
cp inventory/hosts.example.yml inventory/hosts.yml
ansible-playbook playbooks/site.yml --check --diff   # dry run first
ansible-playbook playbooks/site.yml
ansible-playbook playbooks/site.yml --limit jellyfin # one guest
```
