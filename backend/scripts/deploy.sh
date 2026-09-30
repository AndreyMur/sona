#!/usr/bin/env bash
# Deploy the Sona OdiRouter proxy on the target server (aidailyplanner.ru).
# Run from the backend directory:  bash scripts/deploy.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo "Missing .env — copy .env.example and fill in the secrets" >&2
  exit 1
fi

if ! grep -q '^ODIROUTER_API_KEY=..*' .env || grep -q 'sk-replace-me' .env; then
  echo "ODIROUTER_API_KEY is not configured in .env" >&2
  exit 1
fi

echo "==> Building image"
docker compose build --pull app

echo "==> Starting stack"
docker compose up -d --remove-orphans

echo "==> Waiting for health"
for _ in $(seq 1 30); do
  if docker compose exec -T app python -c \
    "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8000/healthz')" >/dev/null 2>&1; then
    echo "Service is healthy"
    break
  fi
  sleep 2
done

docker compose ps
echo "Done. HTTPS will be issued automatically by Caddy for aidailyplanner.ru"
