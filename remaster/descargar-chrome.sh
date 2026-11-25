#!/bin/sh
set -eu

destino=$(realpath "$1")
clave=$(realpath "$2")
repositorio=https://dl.google.com/linux/chrome/deb
temporal=$(mktemp -d)
trap 'rm -rf "$temporal"' EXIT
cd "$temporal"

curl -fsSL --retry 3 "$repositorio/dists/stable/InRelease" -o InRelease
gpgv --keyring "$clave" InRelease
indice=main/binary-amd64/Packages.gz
curl -fsSL --retry 3 "$repositorio/dists/stable/$indice" -o Packages.gz
hash_indice=$(awk -v ruta="$indice" '$3 == ruta && length($1) == 64 { print $1; exit }' InRelease)
printf '%s  Packages.gz\n' "$hash_indice" | sha256sum -c -

gzip -dc Packages.gz > Packages
ruta_paquete=$(awk -v RS='' -F '\n' '$1 == "Package: google-chrome-stable" {
    for (i = 1; i <= NF; i++) if ($i ~ /^Filename: /) { print substr($i, 11); exit }
}' Packages)
hash_paquete=$(awk -v RS='' -F '\n' '$1 == "Package: google-chrome-stable" {
    for (i = 1; i <= NF; i++) if ($i ~ /^SHA256: /) { print substr($i, 9); exit }
}' Packages)
case "$ruta_paquete" in
    pool/main/g/google-chrome-stable/google-chrome-stable_*_amd64.deb) ;;
    *) echo 'El repositorio no contiene el paquete esperado de Chrome.' >&2; exit 1 ;;
esac
curl -fsSL --retry 3 "$repositorio/$ruta_paquete" -o chrome.deb
printf '%s  chrome.deb\n' "$hash_paquete" | sha256sum -c -
install -m 0644 chrome.deb "$destino/google-chrome-stable_amd64.deb"
