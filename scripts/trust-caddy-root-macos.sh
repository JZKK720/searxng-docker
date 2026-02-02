#!/usr/bin/env bash
set -euo pipefail

# Trust Caddy internal root certificate on macOS (system keychain).
# Default path: ./caddy/data/pki/authorities/local/root.crt

CERT_PATH="${1:-./caddy/data/pki/authorities/local/root.crt}"

if [ ! -f "$CERT_PATH" ]; then
  echo "Certificate not found: $CERT_PATH" >&2
  exit 2
fi

echo "Importing certificate into System keychain (requires sudo): $CERT_PATH"
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_PATH"
echo "Imported. You may need to restart browsers to pick up the new trust." 
