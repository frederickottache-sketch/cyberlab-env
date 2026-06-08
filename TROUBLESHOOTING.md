# Cyberlab Troubleshooting — Quick Fixes

---

## Container is not running / keeps restarting

Check what's actually happening:
```bash
docker compose ps                          # See status of all containers
docker compose logs --tail=50 <name>       # See why a specific container failed
# e.g.
docker compose logs --tail=50 attacker
docker compose logs --tail=50 elasticsearch
docker compose logs --tail=50 suricata-ids
```

---

## attacker — "container is not running"

The old container may still be using the original image. Force a full recreate:
```bash
docker compose build attacker
docker compose up -d --force-recreate attacker
docker compose ps attacker                 # Should show 'Up'
docker exec -it attacker bash              # Should work now
```

---

## elasticsearch — Restarting (exit code 1)

Elasticsearch 8.x requires a higher virtual memory limit on the host:
```bash
sudo sysctl -w vm.max_map_count=262144
# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Then restart elasticsearch
docker compose restart elasticsearch
docker compose logs --tail=20 elasticsearch   # Should show 'started'
```

---

## suricata-ids — Restarting

Suricata uses `network_mode: host` and looks for a bridge interface. The interface
may be named `br-xxxxxx` instead of `docker0` on your system.

Find the correct interface name:
```bash
ip -o link show | grep -E 'br-|docker'
```

If it shows something like `br-a1b2c3d4e5f6`, pass it manually:
```bash
docker compose stop suricata-ids
docker run --rm --network host --cap-add NET_ADMIN --cap-add NET_RAW \
  -v $(pwd)/rules/local.rules:/etc/suricata/rules/local.rules:ro \
  -v $(pwd)/configs/suricata/suricata.yaml:/etc/suricata/suricata.yaml:ro \
  jasonish/suricata:latest suricata -i br-<YOUR_ID> --af-packet -l /var/log/suricata
```

Or update the `command:` in `docker-compose.yml` to hardcode your interface name.

---

## dvwa / metasploitable — unreachable at their IP

These containers run on the `cyberlab` bridge network. Commands against them must
come from **inside** the attacker container or another container on the same network.
You cannot ping `172.20.0.10` directly from the host unless you add a route:

```bash
# Option A: Run all attack commands inside the attacker container (recommended)
docker exec -it attacker bash

# Option B: Add a host route to the lab subnet
sudo ip route add 172.20.0.0/24 via $(docker network inspect cyberlab_cyberlab \
  --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
```

---

## "/results/ — permission denied" or "no such file"

The `/results/` path only exists inside containers (mounted from `./results/`).
On the host, the folder is `~/cyberlab-env/results/`.

Fix permissions:
```bash
chmod 777 ~/cyberlab-env/results
```

Always run scan tools from **inside** the attacker container:
```bash
docker exec -it attacker bash
nmap -sn 172.20.0.0/24 -oN /results/host_discovery.txt   # correct
```

---

## Full reset (start from scratch)

```bash
docker compose down -v          # Stop containers AND delete volumes
docker compose build --no-cache # Rebuild attacker image fresh
sudo sysctl -w vm.max_map_count=262144
chmod 777 ~/cyberlab-env/results
docker compose up -d --force-recreate
docker compose ps
```
