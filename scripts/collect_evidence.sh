#!/usr/bin/env bash
# =============================================================
# MIT Cyberlab — Chain of Custody Evidence Logger (Session 4)
# Usage: bash /scripts/collect_evidence.sh <file_path> <description>
# Example: bash /scripts/collect_evidence.sh /results/mem_dump.core "Memory dump from Metasploitable3"
# =============================================================

set -euo pipefail

COC_LOG="/results/chain_of_custody.txt"
mkdir -p /results

FILE="${1:-}"
DESC="${2:-Unspecified evidence item}"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "Usage: $0 <file_path> <description>"
    echo "Error: File '$FILE' not found."
    exit 1
fi

# Auto-increment evidence ID
COUNT=$(grep -c "^Evidence ID" "$COC_LOG" 2>/dev/null || echo 0)
EID=$(printf "E-%03d" $(( COUNT + 1 )))

MD5=$(md5sum "$FILE" | awk '{print $1}')
SHA256=$(sha256sum "$FILE" | awk '{print $1}')
SIZE=$(stat -c%s "$FILE")
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

cat >> "$COC_LOG" << EOF

================================================================
Evidence ID   : $EID
Description   : $DESC
File Path     : $FILE
File Size     : $SIZE bytes
Acquired By   : ${USER:-analyst}
Acquisition   : $(hostname) — manual collection via bash script
Timestamp UTC : $TIMESTAMP
MD5 Hash      : $MD5
SHA-256 Hash  : $SHA256
Verified By   : (analyst to sign)
Storage       : /results/ directory
Transfer Log  : (complete when transferred)
================================================================
EOF

echo "Chain of custody recorded for $EID: $FILE"
echo "  MD5:    $MD5"
echo "  SHA256: $SHA256"
echo "Log appended to: $COC_LOG"
