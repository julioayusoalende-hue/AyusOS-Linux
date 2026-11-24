#!/bin/bash
set -euo pipefail

if (( EUID != 0 )) || (( $# != 2 )); then
    printf 'Uso: sudo %s <ISO estable 1.1> <ISO de salida>\n' "$0" >&2
    exit 2
fi
base=$(realpath -- "$1")
output=$(realpath -m -- "$2")
remaster=$(dirname "$(realpath -- "$0")")
assets=$remaster/calamares
share=$remaster/../config/includes.chroot/usr/share
if [[ -e "$output" || -e "$output.sha256" ]]; then
    printf 'Ya existe la ISO de salida o su archivo SHA-256.\n' >&2
    exit 2
fi

# SHA-256 de la ISO estable 1.1 publicada con el icono del actualizador.
printf '%s  %s\n' 'da3b8a538a4320f4b2feacf13c4ea14be3795c994de28d419f38afcf86120268' "$base" |
    sha256sum -c --strict

# El árbol descomprimido requiere varios GB y conserva propietarios y xattrs.
work=$(mktemp -d -- "$(dirname "$output")/.ayusos-remaster.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
xorriso -osirrox on -indev "$base" \
    -extract /live/filesystem.squashfs "$work/base.squashfs" \
    -extract /live/filesystem.packages "$work/base.packages" \
    -extract /sha256sum.txt "$work/base.sha256"
unsquashfs -processors 4 -no-progress -d "$work/root" "$work/base.squashfs"

version=$(sed -n 's/^Version: //p' "$remaster/release/DEBIAN/control")
dpkg-deb --root-owner-group --build "$remaster/release" "$work/root/tmp/ayusos-release.deb"
dpkg --root="$work/root" --install "$work/root/tmp/ayusos-release.deb"
rm -- "$work/root/tmp/ayusos-release.deb"
branding=$work/root/etc/calamares/branding/ayusos
sed -i -E "/^    (version|shortVersion|versionedName|shortVersionedName):/ s/1\.1/$version/" "$branding/branding.desc"
awk -F '\t' -v OFS='\t' -v version="$version" '
    $1 == "ayusos-release" { $2 = version; found = 1 }
    { print }
    END { if (!found) exit 1 }
' "$work/base.packages" > "$work/filesystem.packages"

install -m 0644 "$assets/show.qml" "$branding/show.qml"
install -m 0644 "$share"/backgrounds/ayusos/*.jpg "$work/root/usr/share/backgrounds/ayusos/"
install -m 0644 "$share"/gnome-background-properties/ayusos-*.xml "$work/root/usr/share/gnome-background-properties/"

mksquashfs "$work/root" "$work/filesystem.squashfs" -noappend -comp zstd \
    -Xcompression-level 3 -b 131072 -processors 4 -no-progress
squashfs_hash=$(sha256sum < "$work/filesystem.squashfs")
packages_hash=$(sha256sum < "$work/filesystem.packages")
awk -v squashfs="${squashfs_hash%% *}" -v packages="${packages_hash%% *}" '
    $2 == "./live/filesystem.squashfs" { print squashfs "  " $2; next }
    $2 == "./live/filesystem.packages" { print packages "  " $2; next }
    { print }
' "$work/base.sha256" > "$work/sha256sum.txt"

xorriso -indev "$base" -outdev "$work/result.iso" \
    -map "$work/filesystem.squashfs" /live/filesystem.squashfs \
    -map "$work/filesystem.packages" /live/filesystem.packages \
    -map "$work/sha256sum.txt" /sha256sum.txt \
    -boot_image any replay
mv -- "$work/result.iso" "$output"
cd "$(dirname "$output")"
sha256sum -- "$(basename "$output")" > "$output.sha256"
