#!/usr/bin/env bash
set -euo pipefail

# Cross-platform wrapper to install the Caddy internal root certificate.
# Delegates to platform-specific helpers in ./scripts.

CERT_PATH="${1:-./caddy/data/pki/authorities/local/root.crt}"

if [ ! -f "$CERT_PATH" ]; then
  echo "Certificate not found: $CERT_PATH" >&2
  exit 2
fi

uname_s=$(uname -s || true)

case "$uname_s" in
  Darwin*)
    echo "Detected macOS — running macOS helper"
    exec sudo "$(dirname "$0")/trust-caddy-root-macos.sh" "$CERT_PATH"
    ;;
  Linux*)
    echo "Detected Linux — running Linux helper"
    exec "$(dirname "$0")/trust-caddy-root-linux.sh" "$CERT_PATH"
    ;;
  CYGWIN*|MINGW*|MSYS*)
    echo "Detected Windows (via MSYS/Cygwin). Invoking PowerShell helper."
    if command -v powershell.exe >/dev/null 2>&1; then
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(pwd)/scripts/trust-caddy-root.ps1" -CertPath "$(pwd)/${CERT_PATH#./}" -Scope CurrentUser
      exit $?
    elif command -v pwsh.exe >/dev/null 2>&1; then
      pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$(pwd)/scripts/trust-caddy-root.ps1" -CertPath "$(pwd)/${CERT_PATH#./}" -Scope CurrentUser
      exit $?
    else
      echo "PowerShell not found. Please run scripts/trust-caddy-root.ps1 manually on Windows." >&2
      exit 3
    fi
    ;;
  *)
    echo "Unsupported OS: $uname_s. Try running the platform-specific helper in ./scripts manually." >&2
    exit 4
    ;;
esac
