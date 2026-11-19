#!/usr/bin/env bash
# Usage: scripts/setup_host.sh [host]   (default: localhost)
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${1:-"localhost"}"

echo "HOST: $HOST"

if [[ -f .env ]] && grep -q '^FRONTEND_APP_VITE_HOST=' .env; then
  sed -i "s/^FRONTEND_APP_VITE_HOST=.*/FRONTEND_APP_VITE_HOST=$HOST/" .env
else
  echo "FRONTEND_APP_VITE_HOST=$HOST" >> .env
fi
echo "Wrote FRONTEND_APP_VITE_HOST ($HOST) to .env"

if [[ -f .env ]] && grep -q '^FRONTEND_APP_VITE_MANAGER_SERVER_HOST=' .env; then
  sed -i "s/^FRONTEND_APP_VITE_MANAGER_SERVER_HOST=.*/FRONTEND_APP_VITE_MANAGER_SERVER_HOST=$HOST/" .env
else
  echo "FRONTEND_APP_VITE_MANAGER_SERVER_HOST=$HOST" >> .env
fi
echo "Wrote FRONTEND_APP_VITE_MANAGER_SERVER_HOST ($HOST) to .env"

if [[ -f .env ]] && grep -q '^VIDEO_CONFERENCE_APP_PHX_HOST=' .env; then
  sed -i "s/^VIDEO_CONFERENCE_APP_PHX_HOST=.*/VIDEO_CONFERENCE_APP_PHX_HOST=$HOST/" .env
else
  echo "VIDEO_CONFERENCE_APP_PHX_HOST=$HOST" >> .env
fi
echo "Wrote VIDEO_CONFERENCE_APP_PHX_HOST ($HOST) to .env"

if [[ -f .env ]] && grep -q '^VIDEO_CONFERENCE_APP_HTTP3_SERVER_HOST=' .env; then
  sed -i "s/^VIDEO_CONFERENCE_APP_HTTP3_SERVER_HOST=.*/VIDEO_CONFERENCE_APP_HTTP3_SERVER_HOST=$HOST/" .env
else
  echo "VIDEO_CONFERENCE_APP_HTTP3_SERVER_HOST=$HOST" >> .env
fi
echo "Wrote VIDEO_CONFERENCE_APP_HTTP3_SERVER_HOST ($HOST) to .env"

