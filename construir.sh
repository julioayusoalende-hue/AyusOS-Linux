#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if (( EUID != 0 )); then
    echo 'Ejecuta sudo ./construir.sh' >&2
    exit 1
fi
exec ./remaster/crear-iso-debian-gnome.sh "$@"
