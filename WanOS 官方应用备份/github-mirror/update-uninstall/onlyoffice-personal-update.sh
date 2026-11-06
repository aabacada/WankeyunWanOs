#!/bin/sh
set -eu

export ONLYOFFICE_PERSONAL_FORCE_ASSETS="${ONLYOFFICE_PERSONAL_FORCE_ASSETS:-0}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/install.sh" ]; then
  exec "$SCRIPT_DIR/install.sh"
fi
exec sh -c "$(curl -fsSL https://wanos.xyz/downloads/apps/onlyoffice-personal/install.sh)"
