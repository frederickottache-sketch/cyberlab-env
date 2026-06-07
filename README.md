# MIT Cyberlab — Cybersecurity Fundamentals Lab Environment

Containerised threat hunting, exploitation, and defence lab for second-semester MIT students.

---

## Quick Start

### Prerequisites
- Ubuntu 22.04/24.04 LTS **or** Kali Linux 2024.x
- 8 GB RAM, 4 CPU cores, 40 GB free disk
- Docker + Docker Compose installed

### 1. Install host dependencies

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git vim net-tools tcpdump wireshark nmap \
    nikto sqlmap hashcat john python3-pip docker.io docker-compose \
    autopsy volatility3 seclists

sudo usermod -aG docker $USER
sudo usermod -aG wireshark $USER
# Log out and back in
```

### 2. Clone and start the lab

```bash
git clone https://github.com/mit-cyberlab/cyberlab-env.git ~/cyberlab
cd ~/cyberlab
docker-compose pull        # ~5 GB download
docker-compose up -d
docker-compose ps          # All containers should show 'Up'
```

### 3. Verify the environment

```bash
bash scripts/verify_setup.sh
```

---

## Lab Network Reference

| Container       | IP Address    | Port(s)        | Credentials             |
|-----------------|---------------|----------------|-------------------------|
| Attacker (Kali) | 172.20.0.5    | —              | —                       |
| DVWA            | 172.20.0.10   | 80             | admin / password        |
| Metasploitable3 | 172.20.0.11   | 21,22,80,445,3306,8080 | vagrant / vagrant |
| Suricata IDS    | 172.20.0.20   | —              | —                       |
| Elasticsearch   | 172.20.0.30   | 9200           | —                       |
| Kibana (SIEM)   | 172.20.0.31   | 5601           | —                       |
| MISP            | 172.20.0.40   | 443            | admin@admin.test / admin |
| OpenVAS         | 172.20.0.50   | 9392           | admin / admin           |

---

## Repository Structure

```
cyberlab-env/
├── docker-compose.yml          # Spins up all 8 lab containers
├── README.md                   # This file
├── rules/
│   └── local.rules             # Custom Suricata detection rules (Session 3)
├── configs/
│   ├── suricata/
│   │   └── suricata.yaml       # Suricata IDS configuration
│   ├── filebeat/
│   │   └── filebeat.yml        # Ships EVE logs → Elasticsearch
│   ├── kibana/
│   │   └── mit-lab-soc-dashboard.ndjson  # Pre-built Kibana dashboard
│   └── misp/
│       └── attack_navigator_layer.json   # MITRE ATT&CK layer (Sessions 1–4)
├── scripts/
│   ├── verify_setup.sh         # Post-startup health check
│   ├── exploit_script.rc       # Metasploit resource file (Session 4)
│   ├── redteam_script.sh       # Automated red team attack chain (Session 5)
│   └── collect_evidence.sh     # Chain-of-custody evidence logger (Session 4)
└── results/                    # All student artefacts saved here (gitignored)
```

---

## Sessions Overview

| Session | Topic | Weeks | Key Tools |
|---------|-------|-------|-----------|
| 1 | Reconnaissance & Vulnerability Assessment | 1–2 | Nmap, OpenVAS, Nikto, Wireshark |
| 2 | Web Application Exploitation (OWASP Top 10) | 2–3 | Burp Suite, sqlmap, Hashcat |
| 3 | Network Traffic Analysis & IDS | 3–4 | Suricata, ELK Stack, Wireshark |
| 4 | Network Exploitation & Forensics | 4–5 | Metasploit, Volatility 3 |
| 5 | Threat Intelligence & Red/Blue Capstone | 6–8 | MISP, ATT&CK Navigator, full SIEM |

---

## Session-by-Session Quick Commands

### Session 1 — Reconnaissance

```bash
# Enter attacker container
docker exec -it attacker bash

# Host discovery
nmap -sn 172.20.0.0/24 -oN /results/host_discovery.txt

# Full scan — DVWA
nmap -sS -sV -sC -O -p- --open -T4 172.20.0.10 -oA /results/dvwa_full_scan

# Full scan — Metasploitable3
nmap -sS -sV -sC -O --open -A -T4 172.20.0.11 -oA /results/meta3_full_scan

# Vulnerability scripts
nmap --script vuln 172.20.0.11 -oN /results/meta3_vuln_scripts.txt

# Web scanning
nikto -h http://172.20.0.10 -output /results/nikto_dvwa.txt -Format txt
```

### Session 2 — Web Exploitation

```bash
docker exec -it attacker bash

# SQL injection (replace PHPSESSID with value from DVWA login)
sqlmap -u 'http://172.20.0.10/vulnerabilities/sqli/?id=1&Submit=Submit' \
       --cookie='PHPSESSID=<your_session_id>; security=low' \
       --dbs --batch --output-dir=/results/sqlmap/

# Dump users table
sqlmap -u 'http://172.20.0.10/vulnerabilities/sqli/?id=1&Submit=Submit' \
       --cookie='PHPSESSID=<your_session_id>; security=low' \
       -D dvwa -T users --dump --batch

# Crack MD5 hashes
hashcat -m 0 /results/dvwa_hashes.txt /usr/share/wordlists/rockyou.txt \
        --outfile /results/cracked_passwords.txt --force
```

### Session 3 — Suricata & SIEM

```bash
# View live Suricata alerts
docker exec -it suricata-ids tail -f /var/log/suricata/eve.json | \
    python3 -c "import sys,json; [print(json.dumps(json.loads(l), indent=2))
    for l in sys.stdin if json.loads(l).get('event_type')=='alert']"

# Reload custom rules after edits
docker exec suricata-ids kill -USR2 $(docker exec suricata-ids pidof suricata)

# Check alert count
docker exec suricata-ids bash -c \
    "cat /var/log/suricata/eve.json | python3 -c \
    \"import sys,json; print(sum(1 for l in sys.stdin if json.loads(l).get('event_type')=='alert'))\""

# Kibana: http://172.20.0.31:5601
# Import dashboard: Stack Management > Saved Objects > Import > configs/kibana/mit-lab-soc-dashboard.ndjson
```

### Session 4 — Exploitation & Forensics

```bash
# Metasploit — ProFTPD exploit
docker exec -it attacker msfconsole -q -r /scripts/exploit_script.rc

# Collect evidence with chain of custody
bash scripts/collect_evidence.sh /results/mem_dump.core "Memory dump Metasploitable3"

# Volatility 3 analysis
vol -f /results/mem_dump.core linux.pslist.PsList
vol -f /results/mem_dump.core linux.netstat.NetStat
vol -f /results/mem_dump.core linux.bash.Bash
vol -f /results/mem_dump.core linux.malfind.Malfind
```

### Session 5 — Red/Blue Capstone

```bash
# Red Team (run from attacker container)
docker exec -it attacker bash /scripts/redteam_script.sh <PHPSESSID>

# Blue Team — live alert monitoring
curl -X GET 'http://172.20.0.30:9200/suricata-*/_search?pretty' \
  -H 'Content-Type: application/json' \
  -d '{"query":{"range":{"@timestamp":{"gte":"now-1h"}}},"sort":[{"@timestamp":{"order":"desc"}}],"size":20}'

# Containment — block attacker IP
sudo iptables -I DOCKER-USER -s 172.20.0.5 -d 172.20.0.11 -j DROP

# MITRE ATT&CK Navigator — import the pre-built layer:
# https://mitre-attack.github.io/attack-navigator/
# File > Open Existing Layer > configs/misp/attack_navigator_layer.json
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Container not starting | `docker-compose restart <name>` |
| DVWA unreachable | `docker-compose restart dvwa && docker network inspect cyberlab_cyberlab` |
| Suricata no alerts | Check interface: `docker exec suricata-ids suricata --list-runmodes` |
| Kibana "No results" | `docker exec suricata-ids systemctl restart filebeat` |
| sqlmap no injection found | Re-login to DVWA, copy fresh `PHPSESSID`, set security to **Low** |
| Metasploit exploit fails | `set SITEPATH /tmp` and retry; verify ProFTPD: `nc 172.20.0.11 21` |
| Hashcat crashes | Add `--force --opencl-device-types=1` for CPU-only mode |
| Volatility wrong profile | Run `vol -f dump.core banners.Banners` first to identify kernel |

---

## Legal Notice

> All attack exercises **must** be performed exclusively against the containers provisioned by this project. Scanning or attacking any external system without written authorisation is illegal under the Computer Misuse Act and equivalent legislation. The lab environment is self-contained and intentionally vulnerable. **Never expose lab containers to the public Internet.**

---

## Stopping the Lab

```bash
docker-compose down          # Stop and remove containers
docker-compose down -v       # Also remove persistent volumes (full reset)
```
