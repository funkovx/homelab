#!/usr/bin/env bash
# Adds this machine's SSH public key to root in LXC containers, going through
# the Proxmox host, so it works when the guests do not know the key yet.
#
#   scripts/add-ssh-key.sh 101 103 104 105 106
#   KEY=~/.ssh/other.pub PVE=root@192.168.10.2 scripts/add-ssh-key.sh 101
#
# Safe to run again: a key that is already there is not added twice.
set -euo pipefail

PVE=${PVE:-root@192.168.10.2}
KEY=${KEY:-$HOME/.ssh/id_ed25519.pub}

if [ $# -eq 0 ]; then
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi
[ -f "$KEY" ] || { echo "public key not found: $KEY" >&2; exit 1; }

for id in "$@"; do
  # The key goes in on stdin, so its text never ends up in a command line
  ssh "$PVE" "pct exec $id -- sh -c 'umask 077; mkdir -p /root/.ssh; touch /root/.ssh/authorized_keys; k=\$(cat); grep -qxF \"\$k\" /root/.ssh/authorized_keys && echo \"$id: already there\" || { echo \"\$k\" >> /root/.ssh/authorized_keys; echo \"$id: added\"; }'" < "$KEY"
  ip=$(ssh "$PVE" "pct exec $id -- hostname -I" | awk '{print $1}')
  # Trust the guest's host key only if it matches what Proxmox sees inside it
  if ! ssh-keygen -F "$ip" >/dev/null; then
    scanned=$(ssh-keyscan -t ed25519 "$ip" 2>/dev/null)
    seen=$(printf '%s\n' "$scanned" | ssh-keygen -lf - | awk '{print $2}')
    real=$(ssh "$PVE" "pct exec $id -- ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub" | awk '{print $2}')
    if [ -n "$seen" ] && [ "$seen" = "$real" ]; then
      printf '%s\n' "$scanned" >> ~/.ssh/known_hosts
    else
      echo "$id: host key of $ip does not match Proxmox ($seen vs $real), not trusting it" >&2
      continue
    fi
  fi
  ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$ip" true && echo "$id: login to $ip works" || echo "$id: login to $ip FAILED" >&2
done
