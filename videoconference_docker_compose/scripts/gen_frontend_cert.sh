#!/usr/bin/env bash
# Generate the self-signed TLS cert used by the nginx frontend (HTTPS on 8443).
# This is a normal web cert (not a WebTransport pin), so a long validity is fine.
#
# Usage: scripts/gen_frontend_cert.sh [days]   (default: 365)
set -euo pipefail
cd "$(dirname "$0")/.."

DAYS="${1:-365}"
mkdir -p certs

openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout certs/frontend.key \
  -x509 -days "$DAYS" -out certs/frontend.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
chmod 644 certs/frontend.key

echo "Frontend cert generated (valid $DAYS days):"
openssl x509 -in certs/frontend.crt -noout -subject -dates
