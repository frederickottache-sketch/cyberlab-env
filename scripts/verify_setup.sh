#!/usr/bin/env bash
# =============================================================
# MIT Cyberlab — Setup & Verification Script
# Run this AFTER docker-compose up -d
# Usage: bash scripts/verify_setup.sh
# =============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "============================================="
echo " MIT Cyberlab — Environment Verification"
echo "============================================="
echo ""

# 1. Docker
echo "--- Docker ---"
if docker info &>/dev/null; then
    pass "Docker daemon is running"
else
    fail "Docker daemon not running: sudo systemctl start docker"
fi

# 2. Containers
echo ""
echo "--- Containers ---"
for name in dvwa metasploitable attacker suricata-ids elasticsearch kibana openvas misp; do
    status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "missing")
    if [[ "$status" == "running" ]]; then
        pass "$name is running"
    else
        fail "$name — status: $status  (run: docker-compose up -d)"
    fi
done

# 3. Network reachability
echo ""
echo "--- Network Reachability ---"
ping_check() {
    local ip=$1 label=$2
    if ping -c1 -W2 "$ip" &>/dev/null; then
        pass "$label ($ip) reachable"
    else
        fail "$label ($ip) unreachable"
    fi
}
ping_check 172.20.0.10 "DVWA"
ping_check 172.20.0.11 "Metasploitable3"
ping_check 172.20.0.30 "Elasticsearch"
ping_check 172.20.0.31 "Kibana"

# 4. HTTP services
echo ""
echo "--- HTTP Services ---"
http_check() {
    local url=$1 label=$2 pattern=$3
    if curl -sk --max-time 5 "$url" | grep -qi "$pattern"; then
        pass "$label up at $url"
    else
        warn "$label may not be ready yet at $url (try again in 60s)"
    fi
}
http_check "http://172.20.0.10/login.php"   "DVWA"          "login"
http_check "http://172.20.0.31:5601"        "Kibana"        "kibana"
http_check "http://172.20.0.30:9200"        "Elasticsearch" "cluster_name"

# 5. Host tools
echo ""
echo "--- Host Tools ---"
tool_check() {
    local cmd=$1
    if command -v "$cmd" &>/dev/null; then
        pass "$cmd found: $(command -v $cmd)"
    else
        fail "$cmd not found — install it before starting"
    fi
}
tool_check nmap
tool_check nikto
tool_check sqlmap
tool_check wireshark
tool_check hashcat
tool_check john
tool_check vol   # Volatility 3

# 6. Results directory
echo ""
echo "--- Results Directory ---"
if [[ -d ./results ]]; then
    pass "./results directory exists (artefacts will be stored here)"
else
    mkdir -p ./results
    pass "./results directory created"
fi

echo ""
echo "============================================="
echo " Verification Complete"
echo " If all checks pass, you are ready to begin."
echo " DVWA:        http://172.20.0.10      (admin/password)"
echo " Kibana:      http://172.20.0.31:5601"
echo " OpenVAS:     https://172.20.0.50:9392 (admin/admin)"
echo " MISP:        https://172.20.0.40     (admin@admin.test/admin)"
echo "============================================="
