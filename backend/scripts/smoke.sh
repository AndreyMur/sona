#!/usr/bin/env bash
# Smoke test a running proxy: health, anonymous registration, config fetch.
# Usage: bash scripts/smoke.sh https://aidailyplanner.ru
set -euo pipefail

BASE_URL="${1:-http://localhost:8000}"
BASE_URL="${BASE_URL%/}"

echo "==> Health"
curl -fsS "$BASE_URL/healthz"; echo

echo "==> Register device"
TOKEN=$(curl -fsS -X POST "$BASE_URL/v1/devices/register" | python -c "import sys,json;print(json.load(sys.stdin)['device_token'])")
echo "device token acquired"

echo "==> Fetch remote config"
curl -fsS "$BASE_URL/v1/config" -H "Authorization: Bearer $TOKEN" | python -c \
  "import sys,json;d=json.load(sys.stdin);print('prompt_version',d['prompt_version'],'| nlu',d['models']['nlu_primary'])"

echo "==> Device info"
curl -fsS "$BASE_URL/v1/me" -H "Authorization: Bearer $TOKEN"; echo

echo "OK"
