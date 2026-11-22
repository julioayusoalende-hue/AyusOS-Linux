#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if (( EUID != 0 )); then echo 'Ejecuta sudo ./construir.sh' >&2; exit 1; fi
if [[ $(dpkg --print-architecture) != amd64 ]]; then echo 'Se necesita un equipo amd64.' >&2; exit 1; fi
command -v lb >/dev/null || { echo 'Instala live-build.' >&2; exit 1; }
destino=$PWD
trabajo=$(mktemp -d "$PWD/compilacion.XXXXXX")
echo "Directorio de compilación: $trabajo"
cp -a config "$trabajo/"
cd "$trabajo"
lb config --distribution trixie --architectures amd64 --binary-images iso-hybrid \
  --archive-areas 'main non-free-firmware' --debian-installer live \
  --iso-application 'AyusOS Linux' --iso-volume AYUSOS_01 \
  --bootappend-live 'boot=live components locales=es_ES.UTF-8 keyboard-layouts=es timezone=Europe/Madrid hostname=ayusos'
lb build
install -m 0644 live-image-amd64.hybrid.iso "$destino/AyusOS-Linux-0.1-amd64.iso"
cd "$destino"
sha256sum AyusOS-Linux-0.1-amd64.iso > AyusOS-Linux-0.1-amd64.iso.sha256
