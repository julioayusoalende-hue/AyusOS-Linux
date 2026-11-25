#!/bin/bash
set -euo pipefail
export LC_ALL=C

uso() {
    printf 'Uso: sudo %s [ISO oficial Debian Live GNOME] [ISO de salida]\n' "$0" >&2
    printf 'Sin argumentos descarga la ISO GNOME actual de Debian 13 y crea la ISO de AyusOS junto al repositorio.\n' >&2
}

if (( EUID != 0 )); then
    echo 'Ejecuta este script con sudo.' >&2
    exit 1
fi
if (( $# > 2 )); then
    uso
    exit 2
fi
if [[ $(dpkg --print-architecture) != amd64 ]]; then
    echo 'Se necesita un equipo amd64.' >&2
    exit 1
fi

for comando in xorriso unsquashfs mksquashfs dpkg-deb dpkg-query dpkg-divert curl gpgv gzip python3 sha256sum md5sum mount umount chroot df awk sed find grep cmp; do
    command -v "$comando" >/dev/null || {
        printf 'Falta el comando %s. Instala xorriso, squashfs-tools, curl, gpgv y python3.\n' "$comando" >&2
        exit 1
    }
done

repositorio=$(cd "$(dirname "$(realpath -- "$0")")/.." && pwd)
version=$(sed -n 's/^Version: //p' "$repositorio/remaster/release/DEBIAN/control")
[[ "$version" =~ ^[0-9][A-Za-z0-9.+~-]*$ ]] || {
    echo 'La versión de AyusOS no es válida.' >&2
    exit 1
}
salida=${AYUSOS_OUTPUT:-${2:-"$repositorio/AyusOS-Linux-$version-amd64.iso"}}
salida=$(realpath -m -- "$salida")
if [[ -e "$salida" || -e "$salida.sha256" ]]; then
    echo 'Ya existe la ISO de salida o su archivo SHA-256.' >&2
    exit 1
fi

base_url=${DEBIAN_LIVE_URL:-https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid}
cache="$repositorio/descargas"
mkdir -p -- "$cache" "$(dirname "$salida")"
trabajo=$(mktemp -d -- "$(dirname "$salida")/.ayusos-debian.XXXXXX")
raiz=$trabajo/raiz
iso=$trabajo/iso
montajes=()
policy_creada=false

limpiar() {
    set +e
    local fallo=0
    for ((i=${#montajes[@]}-1; i>=0; i--)); do
        if ! umount -- "${montajes[i]}"; then
            fallo=1
        fi
    done
    if "$policy_creada"; then
        rm -f -- "$raiz/usr/sbin/policy-rc.d"
    fi
    if (( fallo == 0 )); then
        rm -rf -- "$trabajo"
    else
        printf 'No se pudieron desmontar todos los sistemas de archivos. Se conserva %s para revisarlo.\n' "$trabajo" >&2
    fi
}
trap limpiar EXIT

montar() {
    mount --bind "$1" "$2"
    montajes+=("$2")
    mount --make-private "$2"
}

echo 'Obteniendo y verificando la ISO oficial de Debian Live GNOME...'
curl -fsSL --retry 3 "$base_url/SHA256SUMS" -o "$trabajo/SHA256SUMS"
if (( $# >= 1 )); then
    base=$(realpath -- "$1")
    nombre_base=$(basename -- "$base")
    hash_base=$(awk -v f="$nombre_base" '$2 == f { print $1; exit }' "$trabajo/SHA256SUMS")
    if [[ ! "$hash_base" =~ ^[0-9a-f]{64}$ ]]; then
        hash_real=$(sha256sum -- "$base" | awk '{print $1}')
        nombre_base=$(awk -v h="$hash_real" '$1 == h && $2 ~ /^debian-live-[0-9][^ ]*-amd64-gnome\.iso$/ { print $2; exit }' "$trabajo/SHA256SUMS")
        [[ -n "$nombre_base" ]] || {
            echo 'La ISO no coincide con ninguna ISO oficial GNOME amd64 publicada.' >&2
            exit 1
        }
        hash_base=$hash_real
    fi
else
    nombre_base=$(awk '$2 ~ /^debian-live-[0-9][^ ]*-amd64-gnome\.iso$/ { print $2; exit }' "$trabajo/SHA256SUMS")
    [[ -n "$nombre_base" ]] || {
        echo 'No se encontró la ISO GNOME amd64 en SHA256SUMS.' >&2
        exit 1
    }
    hash_base=$(awk -v f="$nombre_base" '$2 == f { print $1; exit }' "$trabajo/SHA256SUMS")
    base="$cache/$nombre_base"
    if [[ ! -f "$base" ]]; then
        echo "Descargando $nombre_base..."
        curl -fL --retry 3 --continue-at - -o "$base.part" "$base_url/$nombre_base"
        mv -- "$base.part" "$base"
    fi
fi
[[ "$hash_base" =~ ^[0-9a-f]{64}$ ]]
printf '%s  %s\n' "$hash_base" "$base" | sha256sum --check --strict

libres_kb=$(df -Pk -- "$(dirname "$salida")" | awk 'NR == 2 { print $4 }')
if (( libres_kb < 22 * 1024 * 1024 )); then
    printf 'Se necesitan al menos 22 GB libres en %s; hay %s KB.\n' "$(dirname "$salida")" "$libres_kb" >&2
    exit 1
fi

mkdir -p -- "$raiz" "$iso/boot/grub/live-theme" "$iso/isolinux" "$iso/.disk" "$raiz/tmp"
echo "Extrayendo $nombre_base..."
xorriso -osirrox on -indev "$base" \
    -extract /live/filesystem.squashfs "$trabajo/base.squashfs" \
    -extract /live/filesystem.packages "$trabajo/base.packages" \
    -extract /sha256sum.txt "$trabajo/sha256sum.txt" \
    -extract /md5sum.txt "$trabajo/md5sum.txt" \
    -extract /boot/grub/grub.cfg "$iso/boot/grub/grub.cfg" \
    -extract /boot/grub/live-theme/theme.txt "$iso/boot/grub/live-theme/theme.txt" \
    -extract /isolinux/live.cfg "$iso/isolinux/live.cfg" \
    -extract /isolinux/menu.cfg "$iso/isolinux/menu.cfg"
unsquashfs -processors "${WORKERS:-$(nproc)}" -no-progress -d "$raiz" "$trabajo/base.squashfs"
rm -- "$trabajo/base.squashfs"

echo 'Preparando el chroot...'
montar /dev "$raiz/dev"
montar /dev/pts "$raiz/dev/pts"
montar /proc "$raiz/proc"
montar /sys "$raiz/sys"
cp -L -- /etc/resolv.conf "$raiz/etc/resolv.conf"
cp -- /etc/hosts "$raiz/etc/hosts"
if [[ ! -e "$raiz/usr/sbin/policy-rc.d" ]]; then
    printf '#!/bin/sh\nexit 101\n' > "$raiz/usr/sbin/policy-rc.d"
    chmod 0755 "$raiz/usr/sbin/policy-rc.d"
    policy_creada=true
fi

# La ISO Live contiene una fuente file:/run/live/medium que no existe en el chroot.
if [[ -f "$raiz/etc/apt/sources.list" ]]; then
    mv -- "$raiz/etc/apt/sources.list" "$trabajo/sources.list.original"
fi
cat > "$raiz/etc/apt/sources.list.d/zz-sources.list" <<'FUENTES'
deb http://deb.debian.org/debian trixie main non-free-firmware
deb http://deb.debian.org/debian trixie-updates main non-free-firmware
deb http://security.debian.org/debian-security trixie-security main non-free-firmware
FUENTES
opciones_apt=(-o Dir::Etc::sourcelist=/etc/apt/sources.list.d/zz-sources.list -o Dir::Etc::sourceparts=-)

echo 'Incorporando identidad, aplicaciones y configuración de AyusOS...'
cp -a --no-preserve=ownership -- "$repositorio/config/includes.chroot/." "$raiz/"

echo 'Descargando paquetes externos verificados...'
"$repositorio/remaster/descargar-chrome.sh" "$raiz/tmp" "$repositorio/claves/google-linux.gpg"
chrome_deb=$raiz/tmp/google-chrome-stable_amd64.deb
[[ "$(dpkg-deb -f "$chrome_deb" Package)" == google-chrome-stable ]]

repositorio_aio=https://github.com/julioayusoalende-hue/AIO-Debian-GUI
url_aio=$(curl -fsSL --retry 3 -o /dev/null -w '%{url_effective}' "$repositorio_aio/releases/latest")
etiqueta_aio=${url_aio##*/}
[[ "$etiqueta_aio" =~ ^v[0-9][A-Za-z0-9.+~-]*$ ]]
paquete_aio="aio-debian-gui_${etiqueta_aio#v}_all.deb"
curl -fL --retry 3 -o "$raiz/tmp/$paquete_aio" "$repositorio_aio/releases/download/$etiqueta_aio/$paquete_aio"
curl -fL --retry 3 -o "$trabajo/SHA256SUMS-aio" "$repositorio_aio/releases/download/$etiqueta_aio/SHA256SUMS"
hash_aio=$(awk -v f="$paquete_aio" '$2 == f || $2 == "*" f { print $1; exit }' "$trabajo/SHA256SUMS-aio")
[[ "$hash_aio" =~ ^[0-9a-f]{64}$ ]]
printf '%s  %s\n' "$hash_aio" "$raiz/tmp/$paquete_aio" | sha256sum --check --strict
[[ "$(dpkg-deb -f "$raiz/tmp/$paquete_aio" Package)" == aio-debian-gui ]]
aio_deb=$raiz/tmp/$paquete_aio

llavero=ayusos-archive-keyring_1.1_all.deb
curl -fL --retry 3 -o "$raiz/tmp/$llavero" "https://github.com/julioayusoalende-hue/AyusOS-Linux/releases/download/v1.2/$llavero"
printf '%s  %s\n' 'ee89bba66b8d6aec1928cf8c4b436284bf803880ef01a6e352f3f714ffbb85ff' "$raiz/tmp/$llavero" | sha256sum --check --strict

cp -a -- "$repositorio/remaster/branding" "$trabajo/branding"
sed -i "s/^Version: .*/Version: $version/" "$trabajo/branding/DEBIAN/control"
dpkg-deb --root-owner-group --build "$trabajo/branding" "$raiz/tmp/ayusos-branding_${version}_all.deb"
dpkg-deb --root-owner-group --build "$repositorio/remaster/release" "$raiz/tmp/ayusos-release_${version}_all.deb"

mapfile -t paquetes < <(awk 'NF && $1 !~ /^#/ { print $1 }' "$repositorio"/config/package-lists/*.list.chroot | sort -u)
((${#paquetes[@]} > 0))

echo 'Actualizando los índices APT dentro del chroot...'
chroot "$raiz" apt-get "${opciones_apt[@]}" -o APT::Update::Error-Mode=any update
echo 'Comprobando la transacción de paquetes...'
chroot "$raiz" apt-get "${opciones_apt[@]}" -s --no-upgrade --no-install-recommends --no-remove install "${paquetes[@]}" | tee "$trabajo/apt-plan"
if ! awk '$1 == "Remv" { print "Se retiraría un paquete de la base: " $2 > "/dev/stderr"; fallo=1 } END { exit fallo }' "$trabajo/apt-plan"; then
    echo 'La instalación propone retirar paquetes de la base oficial; se aborta.' >&2
    exit 1
fi

echo 'Instalando la selección de aplicaciones de AyusOS...'
DEBIAN_FRONTEND=noninteractive chroot "$raiz" apt-get "${opciones_apt[@]}" -y --no-upgrade --no-install-recommends --no-remove install "${paquetes[@]}"
for deb in "$chrome_deb" "$aio_deb" "$raiz/tmp/ayusos-branding_${version}_all.deb" "$raiz/tmp/ayusos-release_${version}_all.deb" "$raiz/tmp/$llavero"; do
    DEBIAN_FRONTEND=noninteractive chroot "$raiz" apt-get "${opciones_apt[@]}" -y --no-install-recommends --no-remove install "/tmp/$(basename -- "$deb")"
done
chroot "$raiz" apt-get "${opciones_apt[@]}" check
chroot "$raiz" apt-get clean
find "$raiz/var/cache/apt/archives" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

echo 'Aplicando la configuración final del escritorio y del instalador...'
chroot "$raiz" /bin/sh -s < "$repositorio/config/hooks/live/0900-ayusos.hook.chroot"
chroot "$raiz" dconf compile /tmp/gdm-dconf.test /usr/share/gdm/dconf
rm -f -- "$raiz/tmp/gdm-dconf.test"

# Estado temporal que no debe formar parte de la imagen.
rm -f -- "$raiz/etc/apt/sources.list.d/zz-sources.list"
if [[ -f "$trabajo/sources.list.original" ]]; then
    mv -- "$trabajo/sources.list.original" "$raiz/etc/apt/sources.list"
fi
find "$raiz/var/lib/apt/lists" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
find "$raiz/tmp" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
: > "$raiz/etc/resolv.conf"
: > "$raiz/etc/hosts"
: > "$raiz/etc/machine-id"
rm -f -- "$raiz/var/lib/dbus/machine-id"
if "$policy_creada"; then
    rm -f -- "$raiz/usr/sbin/policy-rc.d"
    policy_creada=false
fi

for ((i=${#montajes[@]}-1; i>=0; i--)); do
    umount -- "${montajes[i]}"
done
montajes=()

echo 'Validando los paquetes y archivos críticos...'
for paquete in base-files gnome-shell gdm3 network-manager live-boot live-config live-config-systemd calamares google-chrome-stable gnome-terminal timeshift aio-debian-gui ayusos-branding ayusos-release; do
    [[ "$(dpkg-query --admindir="$raiz/var/lib/dpkg" -W -f='${db:Status-Status}' "$paquete" 2>/dev/null)" == installed ]] || {
        echo "Falta el paquete obligatorio: $paquete" >&2
        exit 1
    }
done
if dpkg-query --admindir="$raiz/var/lib/dpkg" -W -f='${db:Status-Status}\n' kitty 2>/dev/null | grep -qx installed; then
    echo 'Kitty sigue instalado en la imagen.' >&2
    exit 1
fi
[[ -L "$raiz/etc/os-release" && $(readlink "$raiz/etc/os-release") == ayusos-release ]]
[[ -s "$raiz/etc/os-release.debian" ]]
dpkg-divert --admindir="$raiz/var/lib/dpkg" --listpackage /etc/os-release | grep -qx ayusos-release
grep -Fxq "AYUSOS_VERSION=\"$version\"" "$raiz/etc/ayusos-release"
grep -Fq "version: \"$version\"" "$raiz/etc/calamares/branding/ayusos/branding.desc"
grep -Fq 'picture-uri-dark=' "$raiz/etc/dconf/db/local.d/10-ayusos-branding"
grep -Fq 'ayusos-oscuro.jpg' "$raiz/etc/dconf/db/local.d/10-ayusos-branding"
grep -Fq 'org.gnome.Terminal.desktop' "$raiz/etc/dconf/db/local.d/20-ayusos-extensions"
if grep -Fq 'kitty.desktop' "$raiz/etc/dconf/db/local.d/20-ayusos-extensions"; then
    echo 'La configuración del escritorio todavía apunta a Kitty.' >&2
    exit 1
fi
for archivo in \
    "$raiz/usr/share/backgrounds/ayusos/ayusos-claro.jpg" \
    "$raiz/usr/share/backgrounds/ayusos/ayusos-oscuro.jpg" \
    "$raiz/usr/share/applications/aio-debian-gui.desktop" \
    "$raiz/usr/share/applications/org.gnome.Terminal.desktop" \
    "$raiz/usr/share/applications/ayusos-instalar.desktop" \
    "$raiz/usr/share/gdm/dconf/99-zz-ayusos-accent" \
    "$raiz/usr/share/keyrings/ayusos-archive.gpg" \
    "$raiz/etc/apt/sources.list.d/ayusos.sources"; do
    [[ -s "$archivo" ]] || {
        echo "Falta el archivo obligatorio: $archivo" >&2
        exit 1
    }
done
[[ -x "$raiz/usr/lib/ayusos/actualizar-terminal" ]]
[[ -x "$raiz/usr/local/libexec/ayusos-finalizar-instalacion" ]]

dpkg-query --admindir="$raiz/var/lib/dpkg" -W -f='${db:Status-Status}\t${binary:Package}\t${Version}\n' |
    awk -F '\t' '$1 == "installed" { print $2 "\t" $3 }' > "$trabajo/filesystem.packages"

echo 'Creando el nuevo sistema de archivos SquashFS...'
mksquashfs "$raiz" "$trabajo/filesystem.squashfs" -noappend -comp zstd \
    -Xcompression-level 3 -b 131072 -processors "${WORKERS:-$(nproc)}" -no-progress

echo 'Adaptando el arranque y la identidad de la ISO...'
python3 "$repositorio/remaster/ajustar-arranque.py" \
    "$iso/boot/grub/grub.cfg" \
    "$iso/isolinux/live.cfg" \
    "$iso/isolinux/menu.cfg" \
    "$iso/boot/grub/live-theme/theme.txt"
cp -- "$repositorio/config/includes.binary/boot/grub/splash.png" "$iso/boot/grub/splash.png"
cp -- "$repositorio/config/includes.binary/isolinux/splash.png" "$iso/isolinux/splash.png"
printf 'AyusOS Linux %s (base Debian Live GNOME)\n' "$version" > "$iso/.disk/info"
printf 'Remastered from official Debian Live GNOME ISO\nBase: %s\nAyusOS version: %s\n' "$nombre_base" "$version" > "$iso/.disk/generator"

actualizar_suma() {
    local manifiesto=$1 archivo=$2 ruta_iso=$3 algoritmo=$4 hash
    hash=$("$algoritmo"sum -- "$archivo" | awk '{print $1 }')
    awk -v ruta="./$ruta_iso" -v hash="$hash" '
        $2 == ruta { print hash "  " $2; encontrado=1; next }
        { print }
        END { if (!encontrado) print hash "  " ruta }
    ' "$manifiesto" > "$manifiesto.new"
    mv -- "$manifiesto.new" "$manifiesto"
}

modificados=(
    'live/filesystem.squashfs'
    'live/filesystem.packages'
    'boot/grub/grub.cfg'
    'boot/grub/splash.png'
    'boot/grub/live-theme/theme.txt'
    'isolinux/live.cfg'
    'isolinux/menu.cfg'
    'isolinux/splash.png'
    '.disk/info'
    '.disk/generator'
)
for ruta in "${modificados[@]}"; do
    case "$ruta" in
        live/filesystem.squashfs) archivo=$trabajo/filesystem.squashfs ;;
        live/filesystem.packages) archivo=$trabajo/filesystem.packages ;;
        *) archivo=$iso/$ruta ;;
    esac
    actualizar_suma "$trabajo/sha256sum.txt" "$archivo" "$ruta" sha256
    actualizar_suma "$trabajo/md5sum.txt" "$archivo" "$ruta" md5
done

echo 'Reconstruyendo la ISO híbrida...'
xorriso -indev "$base" -outdev "$trabajo/resultado.iso" \
    -volid "AYUSOS_${version//./}" \
    -map "$trabajo/filesystem.squashfs" /live/filesystem.squashfs \
    -map "$trabajo/filesystem.packages" /live/filesystem.packages \
    -map "$trabajo/sha256sum.txt" /sha256sum.txt \
    -map "$trabajo/md5sum.txt" /md5sum.txt \
    -map "$iso/boot/grub/grub.cfg" /boot/grub/grub.cfg \
    -map "$iso/boot/grub/splash.png" /boot/grub/splash.png \
    -map "$iso/boot/grub/live-theme/theme.txt" /boot/grub/live-theme/theme.txt \
    -map "$iso/isolinux/live.cfg" /isolinux/live.cfg \
    -map "$iso/isolinux/menu.cfg" /isolinux/menu.cfg \
    -map "$iso/isolinux/splash.png" /isolinux/splash.png \
    -map "$iso/.disk/info" /.disk/info \
    -map "$iso/.disk/generator" /.disk/generator \
    -boot_image any replay

xorriso -osirrox on -indev "$trabajo/resultado.iso" -extract /sha256sum.txt "$trabajo/sha256sum.final"
xorriso -osirrox on -indev "$trabajo/resultado.iso" -extract /md5sum.txt "$trabajo/md5sum.final"
cmp -- "$trabajo/sha256sum.txt" "$trabajo/sha256sum.final"
cmp -- "$trabajo/md5sum.txt" "$trabajo/md5sum.final"
xorriso -indev "$trabajo/resultado.iso" -report_el_torito plain

mv -- "$trabajo/resultado.iso" "$salida"
cd -- "$(dirname "$salida")"
sha256sum -- "$(basename "$salida")" > "$salida.sha256"
if [[ -n ${SUDO_UID:-} && -n ${SUDO_GID:-} ]]; then
    chown "$SUDO_UID:$SUDO_GID" -- "$salida" "$salida.sha256"
fi
printf '\nISO creada: %s\nSHA-256: %s\n' "$salida" "$(awk '{print $1}' "$salida.sha256")"
