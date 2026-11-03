#!/usr/bin/env bash
# Debug helper: captures only the Poulplan window through the VM service.
# Usage: tool/app_screenshot.sh <vm-service-url> <output.png> [key=value ...]
#   keys: route=/settings  view=day|week|month|year|agenda  day=2026-11-03
set -euo pipefail
url="${1%/}"; out="$2"; shift 2
isolate=$(curl -s "$url/getVM" | python3 -c 'import json,sys; print([i["id"] for i in json.load(sys.stdin)["result"]["isolates"] if i["name"]=="main"][0])')
args=(--data-urlencode "isolateId=$isolate" --data-urlencode "path=$out")
for kv in "$@"; do args+=(--data-urlencode "$kv"); done
curl -s -G "$url/ext.poulplan.screenshot" "${args[@]}"
echo
