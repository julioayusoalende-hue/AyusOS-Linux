#!/bin/bash
set -euo pipefail

if (( EUID != 0 || $# != 2 )); then
    printf 'Uso: sudo %s <ISO oficial 1.2> <ISO nueva>\n' "$0" >&2
    exit 2
fi
base=$(realpath -- "$1")
output=$(realpath -m -- "$2")
remaster=$(dirname "$(realpath -- "$0")")
share=$remaster/../config/includes.chroot/usr/share
[[ ! -e "$output" && ! -e "$output.sha256" ]]
printf '%s  %s\n' '84e286427fc595af6d6fc7601a5c0933380f8b4dea1fa2b8506996a93a267751' "$base" | sha256sum --check --strict
work=$(mktemp -d -- "$(dirname "$output")/.ayusos-remaster.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
root=$work/root
xorriso -osirrox on -indev "$base" \
    -extract /live/filesystem.squashfs "$work/base.squashfs" \
    -extract /live/filesystem.packages "$work/base.packages" \
    -extract /sha256sum.txt "$work/base.sha256"
unsquashfs -processors 4 -no-progress -d "$root" "$work/base.squashfs"
rm -- "$work/base.squashfs"

repo=https://github.com/julioayusoalende-hue/AIO-Debian-GUI
url=$(curl -fsSL --retry 3 -o /dev/null -w '%{url_effective}' "$repo/releases/latest")
tag=${url##*/}
[[ $tag =~ ^v[0-9][A-Za-z0-9.+~-]*$ ]]
asset=aio-debian-gui_${tag#v}_all.deb
curl -fL --retry 3 -o "$root/tmp/$asset" "$repo/releases/download/$tag/$asset"
curl -fL --retry 3 -o "$work/SHA256SUMS" "$repo/releases/download/$tag/SHA256SUMS"
hash=$(awk -v f="$asset" '$2 == f || $2 == "*" f { print $1 }' "$work/SHA256SUMS")
[[ $hash =~ ^[0-9a-f]{64}$ ]]
printf '%s  %s\n' "$hash" "$root/tmp/$asset" | sha256sum --check --strict
[[ $(dpkg-deb -f "$root/tmp/$asset" Package) == aio-debian-gui ]]
aio=$(dpkg-deb -f "$root/tmp/$asset" Version)
old=$(awk '$1 == "aio-debian-gui" { print $2 }' "$work/base.packages")
dpkg --compare-versions "$aio" ge "$old"
printf 'AiO Debian GUI: %s -> %s\n' "$old" "$aio"

# Usar solo Debian firmado para resolver dependencias nuevas. No actualizar el resto.
apt_opts=(-o Dir::Etc::sourcelist=/etc/apt/sources.list.d/zz-sources.list -o Dir::Etc::sourceparts=-)
cp -L -- /etc/resolv.conf "$root/etc/resolv.conf"
chroot "$root" apt-get "${apt_opts[@]}" -o APT::Update::Error-Mode=any update
chroot "$root" apt-get "${apt_opts[@]}" -s --no-install-recommends --no-remove install "/tmp/$asset" gnome-terminal | tee "$work/apt-plan"
awk '$1 == "Inst" && $3 ~ /^\[/ && $2 != "aio-debian-gui" { print "Actualización no prevista: " $2 > "/dev/stderr"; fail=1 } END { exit fail }' "$work/apt-plan"
DEBIAN_FRONTEND=noninteractive chroot "$root" apt-get "${apt_opts[@]}" -y --no-install-recommends --no-remove install "/tmp/$asset" gnome-terminal
rm -- "$root/tmp/$asset"
chroot "$root" apt-get clean
: > "$root/etc/resolv.conf"
find "$root/var/lib/apt/lists" -maxdepth 1 -type f ! -name lock -delete

# Actualizar el paquete de la distro y su lanzador antes de retirar Kitty.
cp -a "$remaster/release" "$work/release"
sed -i 's/^Version: 1\.2$/Version: 1.3/' "$work/release/DEBIAN/control"
sed -i -e '/^PRETTY_NAME=/ s/1\.2/1.3/' -e 's/^AYUSOS_VERSION="1\.2"$/AYUSOS_VERSION="1.3"/' "$work/release/etc/ayusos-release"
dpkg-deb --root-owner-group --build "$work/release" "$root/tmp/ayusos-release.deb"
dpkg --root="$root" --install "$root/tmp/ayusos-release.deb"
rm -- "$root/tmp/ayusos-release.deb"
dpkg --root="$root" --purge kitty kitty-shell-integration kitty-terminfo
# El llavero oficial instala también ayusos.sources en el sistema que copia Calamares.
keyring=ayusos-archive-keyring_1.1_all.deb
curl -fL --retry 3 -o "$root/tmp/$keyring" "https://github.com/julioayusoalende-hue/AyusOS-Linux/releases/download/v1.2/$keyring"
printf '%s  %s\n' 'ee89bba66b8d6aec1928cf8c4b436284bf803880ef01a6e352f3f714ffbb85ff' "$root/tmp/$keyring" | sha256sum --check --strict
dpkg --root="$root" --install "$root/tmp/$keyring"
rm -- "$root/tmp/$keyring"
grep -Fx 'Signed-By: /usr/share/keyrings/ayusos-archive.gpg' "$root/etc/apt/sources.list.d/ayusos.sources"
test -s "$root/usr/share/keyrings/ayusos-archive.gpg"
chroot "$root" apt-get check
chroot "$root" update-alternatives --set x-terminal-emulator /usr/bin/gnome-terminal.wrapper
sed -i 's/\bkitty\.desktop\b/org.gnome.Terminal.desktop/g' "$root/etc/dconf/db/local.d/20-ayusos-extensions"
# GDM usa su propio perfil, compilado al arrancar. Tomar el acento del escritorio.
accent=$(grep -xE "accent-color='(blue|teal|green|yellow|orange|pink|red|purple|slate)'" "$root/etc/dconf/db/local.d/30-ayusos-yaru")
printf '[org/gnome/desktop/interface]\n%s\n' "$accent" > "$root/usr/share/gdm/dconf/99-zz-ayusos-accent"
branding=$root/etc/calamares/branding/ayusos
sed -i -E '/^    (version|shortVersion|versionedName|shortVersionedName):/ s/1\.2/1.3/' "$branding/branding.desc"
install -m 0644 "$share"/backgrounds/ayusos/ayusos-{claro,oscuro}.jpg "$root/usr/share/backgrounds/ayusos/"
install -m 0644 "$share/gnome-background-properties/ayusos.xml" "$root/usr/share/gnome-background-properties/ayusos-13.xml"
# Cambiar únicamente los fondos del escritorio; mantener el bloqueo y el resto de dconf.
sed -i -e '/^\[org\/gnome\/desktop\/background\]/,/^\[/ { /^picture-uri=/ s/granate\.png/ayusos-claro.jpg/; /^picture-uri-dark=/ s/granate\.png/ayusos-oscuro.jpg/; }' \
    "$root/etc/dconf/db/local.d/10-ayusos-branding"
chroot "$root" dconf update

dpkg-query --admindir="$root/var/lib/dpkg" -W -f='${db:Status-Status}\t${binary:Package}\t${Version}\n' |
    awk -F '\t' '$1 == "installed" { print $2 "\t" $3 }' > "$work/filesystem.packages"
# Conservar todos los paquetes de la base excepto las tres retiradas de Kitty.
awk -F '\t' 'NR==FNR { actual[$1]=$2; next } $1 !~ /^(aio-debian-gui|ayusos-release|kitty|kitty-shell-integration|kitty-terminfo)$/ && actual[$1]!=$2 { print "Paquete base alterado: " $0 > "/dev/stderr"; fail=1 } END { exit fail }' \
    "$work/filesystem.packages" "$work/base.packages"
grep -Fx $'calamares\t3.3.14-1' "$work/filesystem.packages"
grep -Fx $'ayusos-release\t1.3' "$work/filesystem.packages"
grep -E '^gnome-terminal\s' "$work/filesystem.packages"
if grep -E '^kitty(-shell-integration|-terminfo)?\s' "$work/filesystem.packages"; then
    echo 'Kitty sigue instalado.' >&2
    exit 1
fi
test -s "$root/usr/share/applications/org.gnome.Terminal.desktop"
test -x "$root/usr/lib/ayusos/actualizar-terminal"
grep -F 'org.gnome.Terminal.desktop' "$root/etc/dconf/db/local.d/20-ayusos-extensions"
chroot "$root" dconf compile /tmp/gdm-dconf.test /usr/share/gdm/dconf
rm -- "$root/tmp/gdm-dconf.test"
test -s "$branding/show.qml"
grep -F 'picture-uri-dark=' "$root/etc/dconf/db/local.d/10-ayusos-branding" | grep -F 'ayusos-oscuro.jpg'
grep -Fx "$(printf 'aio-debian-gui\t%s' "$aio")" "$work/filesystem.packages"

mksquashfs "$root" "$work/filesystem.squashfs" -noappend -comp zstd \
    -Xcompression-level 3 -b 131072 -processors 4 -no-progress
squashfs_hash=$(sha256sum < "$work/filesystem.squashfs")
packages_hash=$(sha256sum < "$work/filesystem.packages")
awk -v squashfs="${squashfs_hash%% *}" -v packages="${packages_hash%% *}" '
    $2 == "./live/filesystem.squashfs" { print squashfs "  " $2; s++; next }
    $2 == "./live/filesystem.packages" { print packages "  " $2; p++; next }
    { print }
    END { if (s != 1 || p != 1) exit 1 }
' "$work/base.sha256" > "$work/sha256sum.txt"
xorriso -indev "$base" -outdev "$work/result.iso" \
    -map "$work/filesystem.squashfs" /live/filesystem.squashfs \
    -map "$work/filesystem.packages" /live/filesystem.packages \
    -map "$work/sha256sum.txt" /sha256sum.txt \
    -boot_image any replay
mv -- "$work/result.iso" "$output"
cd "$(dirname "$output")"
sha256sum -- "$(basename "$output")" > "$output.sha256"
