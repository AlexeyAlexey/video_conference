#!/usr/bin/env bash
# Generate all certificates/keys required by the stack into certs/:
#   - media cert   (http3_server + video_conference HTTPS)  [12-day, WebTransport pin]
#   - frontend cert (nginx HTTPS)                            [365-day]
#   - JWT keypair  (video_conference <-> http3_server)
#
# Usage: scripts/gen_all_certs.sh [HOST] (default: localhost)
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/gen_media_cert.sh
./scripts/gen_frontend_cert.sh
./scripts/gen_jwt_keys.sh
./scripts/setup_host.sh "$1"
./scripts/video_conference_app.sh

echo
echo "All certs generated in certs/:"
ls -1 certs/
echo
echo "Next: docker compose up -d"
echo "      (or: docker compose up -d --force-recreate to reload certs into running containers)"
