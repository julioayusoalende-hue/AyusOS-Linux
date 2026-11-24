#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if (( EUID != 0 )); then echo 'Ejecuta sudo ./construir.sh' >&2; exit 1; fi
if [[ $(dpkg --print-architecture) != amd64 ]]; then echo 'Se necesita un equipo amd64.' >&2; exit 1; fi
command -v lb >/dev/null || { echo 'Instala live-build.' >&2; exit 1; }
version=1.3
destino=$PWD
trabajo=$(mktemp -d "$PWD/compilacion.XXXXXX")
echo "Directorio de compilación: $trabajo"
cp -a config "$trabajo/"
mkdir -p "$trabajo/config/includes.chroot/etc"
cd "$trabajo"
lb config --distribution trixie --architectures amd64 --binary-images iso-hybrid \
  --archive-areas 'main non-free-firmware' --debian-installer live \
  --mirror-bootstrap http://deb.debian.org/debian/ --mirror-chroot http://deb.debian.org/debian/ \
  --mirror-chroot-security http://deb.debian.org/debian-security/ --mirror-binary http://deb.debian.org/debian/ \
  --mirror-binary-security http://deb.debian.org/debian-security/ \
  --debootstrap-options '--include=gnupg,ca-certificates' \
  --iso-application 'AyusOS Linux' --iso-volume AYUSOS_${version//./} \
  --bootappend-live 'boot=live components locales=es_ES.UTF-8 keyboard-layouts=es timezone=Europe/Madrid hostname=ayusos'
# live-build instala los DEB locales y resuelve sus dependencias en el chroot.
# Se integra siempre la última versión estable publicada de AiO Debian GUI.
repo=https://github.com/julioayusoalende-hue/AIO-Debian-GUI
tag=$(basename "$(curl --fail --silent --location --output /dev/null --write-out '%{url_effective}' "$repo/releases/latest")")
[[ $tag =~ ^v[0-9][A-Za-z0-9.+~-]*$ ]] || { echo "Etiqueta de AiO no válida: $tag" >&2; exit 1; }
aio_version=${tag#v}
aio_deb=aio-debian-gui_${aio_version}_all.deb
echo "AiO Debian GUI: $aio_version"
mkdir -p config/packages.chroot
curl --fail --location --retry 3 --output "config/packages.chroot/$aio_deb" "$repo/releases/download/$tag/$aio_deb"
curl --fail --location --retry 3 --output SHA256SUMS "$repo/releases/download/$tag/SHA256SUMS"
esperado=$(awk -v f="$aio_deb" '$2 == f || $2 == "*" f { print $1 }' SHA256SUMS)
[[ $esperado =~ ^[0-9a-f]{64}$ ]] || { echo "SHA256SUMS no incluye $aio_deb" >&2; exit 1; }
printf '%s  %s\n' "$esperado" "config/packages.chroot/$aio_deb" | sha256sum --check
printf 'AIO_DEBIAN_GUI_VERSION=%s\n' "$aio_version" > config/includes.chroot/etc/ayusos-aio-version
lb build
install -m 0644 live-image-amd64.hybrid.iso "$destino/AyusOS-Linux-$version-amd64.iso"
cd "$destino"
sha256sum AyusOS-Linux-$version-amd64.iso > AyusOS-Linux-$version-amd64.iso.sha256
