#!/usr/bin/env bash
# Pins the TMDB addresses for the jellyfin container (see extra_hosts in compose.yml).
#
# TMDB's DNS answers resolvers in Russia with 127.0.0.1, while the servers
# themselves are reachable. This asks Google DNS for the answers clients in
# other countries get, writes them to .env next to compose.yml and recreates
# Jellyfin only when an address changed. Run daily by tmdb-hosts.timer.
#
# Most image.tmdb.org edges are throttled by the ISP: headers arrive, the body
# stalls. So for images every candidate is tried with a real poster download.
set -euo pipefail
cd "$(dirname "$0")"

# Same files as compose_files in the Ansible inventory
compose=(docker compose -f compose.yml -f compose.vaapi.yml)
# Client subnets in different regions; Google DNS answers as if asked from there
subnets=(8.8.8.0/24 1.1.1.0/24 46.4.0.0/24 81.2.69.0/24 103.10.0.0/24 177.0.0.0/24 2.56.0.0/24)
# Fight Club poster, ~90 KB: large enough that a throttled edge never finishes it
test_image=/t/p/w500/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg

lookup() { # host subnet -> public IPv4 addresses
  curl -fsS -m 10 "https://dns.google/resolve?name=$1&type=A&edns_client_subnet=$2" |
    python3 -I -c '
import ipaddress, json, sys
for a in json.load(sys.stdin).get("Answer", []):
    if a["type"] == 1 and ipaddress.ip_address(a["data"]).is_global:
        print(a["data"])'
}

answers() { # host ip -> success if the server answers HTTPS at that address
  local code
  code=$(curl -sS -m 8 -o /dev/null -w '%{http_code}' --resolve "$1:443:$2" "https://$1/" 2>/dev/null) || return 1
  [ "$code" != 000 ]
}

working_address() { # host var -> current address while it answers, else the first that does
  local current net ip
  current=$(sed -n "s/^$2=//p" .env 2>/dev/null || true)
  [ -n "$current" ] && answers "$1" "$current" && { echo "$current"; return 0; }
  for net in "${subnets[@]}"; do
    for ip in $(lookup "$1" "$net" 2>/dev/null); do
      answers "$1" "$ip" && { echo "$ip"; return 0; }
    done
  done
  return 1
}

delivers() { # ip -> success if this image.tmdb.org edge sends the whole test poster
  local size
  size=$(curl -fsS -m 8 -o /dev/null -w '%{size_download}' \
    --resolve "image.tmdb.org:443:$1" "https://image.tmdb.org$test_image" 2>/dev/null) || return 1
  [ "${size:-0}" -gt 50000 ]
}

fast_image_edge() { # -> an image.tmdb.org edge that is not throttled
  local current round net ip
  local -A tried=()
  # Keep the current edge while it works, so Jellyfin is not restarted for nothing
  current=$(sed -n 's/^TMDB_IMAGE_IP=//p' .env 2>/dev/null || true)
  [ -n "$current" ] && delivers "$current" && { echo "$current"; return 0; }
  [ -n "$current" ] && tried[$current]=1
  # The CDN rotates edges every ~40 s, so ask every region a few times
  for round in 1 2 3; do
    for net in "${subnets[@]}"; do
      for ip in $(lookup image.tmdb.org "$net" 2>/dev/null); do
        [ -n "${tried[$ip]:-}" ] && continue
        tried[$ip]=1
        delivers "$ip" && { echo "$ip"; return 0; }
      done
    done
    [ "$round" -lt 3 ] && sleep 45
  done
  return 1
}

new=$(mktemp)
trap 'rm -f "$new"' EXIT
echo "# Written by tmdb-hosts.sh, do not edit" > "$new"

for var in TMDB_API_IP TMDB_IMAGE_IP TMDB_WWW_IP; do
  case $var in
    TMDB_API_IP) ip=$(working_address api.themoviedb.org "$var" || true) ;;
    TMDB_IMAGE_IP) ip=$(fast_image_edge || true) ;;
    TMDB_WWW_IP) ip=$(working_address www.themoviedb.org "$var" || true) ;;
  esac
  if [ -z "$ip" ]; then
    # Keep the last good address rather than falling back to 127.0.0.1
    ip=$(sed -n "s/^$var=//p" .env 2>/dev/null || true)
    [ -n "$ip" ] || { echo "no address for $var" >&2; exit 1; }
    echo "$var: lookup failed, keeping $ip" >&2
  fi
  echo "$var=$ip" >> "$new"
done

if cmp -s "$new" .env; then
  echo "TMDB addresses unchanged"
  exit 0
fi

install -m 0644 "$new" .env
cat .env
"${compose[@]}" up -d
