#!/bin/bash
set -euo pipefail

# Compatibilidad con las recetas anteriores: ahora toda compilación parte de
# la ISO Live GNOME oficial de Debian 13.
exec "$(dirname "$(realpath -- "$0")")/crear-iso-debian-gnome.sh" "$@"
