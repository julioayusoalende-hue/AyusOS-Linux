# AyusOS Linux 0.1
Edición preliminar para PC Intel y AMD de 64 bits. Usa Debian 13 (trixie), GNOME, GDM y NetworkManager. La sesión Live arranca en español de España y usa la zona horaria Europe/Madrid. El menú de arranque se configura con el instalador Debian en modo Live.

## Generar la ISO
En una instalación Debian 13 amd64 con acceso a los repositorios Debian y espacio para el sistema descomprimido y la ISO, abre una terminal en esta carpeta y ejecuta:

    sudo apt update
    sudo apt install live-build
    sudo ./construir.sh

El proceso crea AyusOS-Linux-0.1-amd64.iso y su suma SHA-256 junto al script. Cada ejecución trabaja en un directorio compilacion.* independiente. Si la compilación se interrumpe, entra en ese directorio y ejecuta sudo lb clean --purge para desmontar y limpiar el entorno antes de eliminarlo.

## Primera prueba
Comprueba la imagen con sha256sum -c AyusOS-Linux-0.1-amd64.iso.sha256. En GNOME Cajas, crea una máquina virtual desde la ISO, asigna 4 GB de RAM y arranca la sesión Live. Comprueba el idioma, el teclado y el nombre del sistema en Configuración → Sistema → Acerca de. Para probar la instalación, reinicia desde la ISO, selecciona el instalador y usa un disco virtual vacío. Expulsa la ISO al terminar y verifica el arranque desde el disco.

## Personalización
Edita config/package-lists/escritorio.list.chroot para cambiar las aplicaciones. El hook en config/hooks/live configura la identidad del sistema y el idioma. Los paquetes se descargan de los repositorios de Debian durante la compilación.
