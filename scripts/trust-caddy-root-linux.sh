#!/usr/bin/env bash
set -euo pipefail

# Trust Caddy internal root certificate on Linux distributions.
# Default path: ./caddy/data/pki/authorities/local/root.crt (repo root)

CERT_PATH="${1:-./caddy/data/pki/authorities/local/root.crt}"

if [ ! -f "$CERT_PATH" ]; then
  echo "Certificate not found: $CERT_PATH" >&2
  exit 2
fi

echo "Installing certificate from: $CERT_PATH"

if command -v update-ca-certificates >/dev/null 2>&1; then
  # Debian/Ubuntu
  sudo cp "$CERT_PATH" /usr/local/share/ca-certificates/searxng-root.crt
  sudo update-ca-certificates
  echo "Installed to /usr/local/share/ca-certificates and updated CA store."
  exit 0
fi

if command -v update-ca-trust >/dev/null 2>&1; then
  # RHEL/CentOS/Fedora
  sudo cp "$CERT_PATH" /etc/pki/ca-trust/source/anchors/searxng-root.crt
  sudo update-ca-trust extract
  echo "Installed to /etc/pki/ca-trust/source/anchors and updated CA trust."
  exit 0
fi

echo "Could not find a supported CA update tool (update-ca-certificates or update-ca-trust)." >&2
echo "Please install the certificate manually or run the appropriate commands for your distro." >&2
exit 3
