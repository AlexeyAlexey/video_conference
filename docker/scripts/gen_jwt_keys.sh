#!/usr/bin/env bash
# Generate the RSA keypair used for JWT auth between video_conference and
# http3_server:
#   - video_conference SIGNS tokens with the PRIVATE key
#   - http3_server     VERIFIES tokens with the PUBLIC key
#
# Both are written to certs/ and read by the apps at runtime.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p certs

# 2048-bit RSA private key (PKCS#8, unencrypted).
# NOTE: world-readable (644) so the container's `nobody` user can read it when
# the app runs. This is a local-dev setup; tighten permissions for production.
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out certs/telephone_switchboard_private_key.pem
chmod 644 certs/telephone_switchboard_private_key.pem

# Derive the matching public key.
openssl pkey -in certs/telephone_switchboard_private_key.pem \
  -pubout -out certs/jwt_local_host_public_key.pem
chmod 644 certs/jwt_local_host_public_key.pem

echo "JWT keypair generated:"
echo "  private (video_conference): certs/telephone_switchboard_private_key.pem"
echo "  public  (http3_server):     certs/jwt_local_host_public_key.pem"
