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
# live-build instala los DEB locales y resuelve sus dependencias en el chroot.
aio_deb=aio-debian-gui_1.1.6_all.deb
mkdir -p config/packages.chroot
curl --fail --location --retry 3 --output "config/packages.chroot/$aio_deb" \
  "https://github.com/julioayusoalende-hue/AIO-Debian-GUI/releases/download/v1.1.6/$aio_deb"
printf '%s  %s\n' '2e032b518dd9beebe5b6055468f0b3b163cc02cf778931687f55e144cab425b5' \
  "config/packages.chroot/$aio_deb" | sha256sum --check
lb build
install -m 0644 live-image-amd64.hybrid.iso "$destino/AyusOS-Linux-0.1-amd64.iso"
cd "$destino"
sha256sum AyusOS-Linux-0.1-amd64.iso > AyusOS-Linux-0.1-amd64.iso.sha256
