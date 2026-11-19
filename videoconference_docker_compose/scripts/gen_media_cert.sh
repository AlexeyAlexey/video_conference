#!/usr/bin/env bash
# Generate the self-signed TLS cert used by http3_server (WebTransport) and
# video_conference (HTTPS). Also compute the SHA-256 cert hash the browser pins
# and write it to .env (HTTP3_SERVER_CERT_HASH).
#
# IMPORTANT: the cert MUST be <= 12 days (2 weeks) valid, otherwise the browser
# refuses `serverCertificateHashes` pinning (W3C WebTransport spec).
#
# Usage: scripts/gen_media_cert.sh [days]   (default: 12)
set -euo pipefail
cd "$(dirname "$0")/.."

DAYS="${1:-12}"
mkdir -p certs

# 1) EC self-signed cert (CN=localhost, SAN localhost + 127.0.0.1).
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout certs/server.key \
  -x509 -days "$DAYS" -out certs/server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
chmod 644 certs/server.key

# 2) SHA-256 of the DER-encoded cert (what the browser pins).
HASH="$(openssl x509 -in certs/server.crt -outform der | openssl dgst -sha256 -hex | sed 's/.*=//')"
echo "Media cert SHA-256 hash: $HASH"
openssl x509 -in certs/server.crt -noout -dates

# 3) Write/update VIDEO_CONFERENCE_APP_HTTP3_SERVER_CERT_HASH in .env (docker compose reads it).
if [[ -f .env ]] && grep -q '^VIDEO_CONFERENCE_APP_HTTP3_SERVER_CERT_HASH=' .env; then
  sed -i "s/^VIDEO_CONFERENCE_APP_HTTP3_SERVER_CERT_HASH=.*/VIDEO_CONFERENCE_APP_HTTP3_SERVER_CERT_HASH=$HASH/" .env
else
  echo "VIDEO_CONFERENCE_APP_HTTP3_SERVER_CERT_HASH=$HASH" >> .env
fi
echo "Wrote VIDEO_CONFERENCE_APP_HTTP3_SERVER_CERT_HASH to .env"
echo "Done. Cert expires in $DAYS days — re-run this script before then."
