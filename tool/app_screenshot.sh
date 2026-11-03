#!/usr/bin/env bash
# Debug helper: captures only the Poulplan window through the VM service.
# Usage: tool/app_screenshot.sh <vm-service-url> <output.png>
set -euo pipefail
url="${1%/}"; out="$2"
isolate=$(curl -s "$url/getVM" | python3 -c 'import json,sys; print([i["id"] for i in json.load(sys.stdin)["result"]["isolates"] if i["name"]=="main"][0])')
curl -s -G "$url/ext.poulplan.screenshot" --data-urlencode "isolateId=$isolate" --data-urlencode "path=$out"
echo
