<div align="center">

<img src="https://raw.githubusercontent.com/julioayusoalende-hue/AIO-Debian-GUI/v1.1.6/package/usr/share/aio-debian-gui/ayusos-logo.png" width="144" alt="Logotipo de AyusOS Linux">

# AyusOS Linux

**Debian 13 estable · GNOME en español · AiO Debian GUI**

Un escritorio para trabajar y una herramienta gráfica para mantenerlo. Arranca AyusOS desde un USB, explora GNOME y decide cuándo instalarlo.

[El escritorio](#el-escritorio) · [AiO Debian GUI](#aio-debian-gui) · [Construir la ISO](#construir-la-iso)

</div>

---

**Candidata sobre Debian Live GNOME para amd64.** Se remasteriza la ISO Live oficial de Debian 13 con GNOME y se le aplica la identidad, las aplicaciones y la configuración de AyusOS. La candidata no sustituye la descarga pública hasta que se compruebe su funcionamiento.

## Construir AyusOS Linux 1.3 sobre Debian Live GNOME

AyusOS ya no construye el escritorio desde cero con `live-build`. La ISO parte de la **ISO Live oficial de Debian 13 con GNOME**, conservando su base completa: kernel, firmware, servicios, escritorio, Calamares y aplicaciones de Debian. Después se aplican la identidad de AyusOS, la selección de aplicaciones, los fondos, las extensiones, el recorrido de instalación y AiO Debian GUI.

Ventajas de esta base:

- Se mantiene la integración oficial de GNOME, GDM, NetworkManager, impresión, audio, firmware y Calamares.
- Los paquetes que ya están en la ISO oficial no se actualizan durante el remasterizado; solo se añaden las aplicaciones de AyusOS y las dependencias necesarias.
- La instalación copia un sistema Live completo, no un escritorio mínimo reconstruido.
- Las actualizaciones de Debian estable siguen siendo la base del sistema.
- La compilación verifica la ISO oficial con `SHA256SUMS` y AiO Debian GUI con su `SHA256SUMS` antes de instalarlos.

Necesitas Debian 13 amd64, conexión a Internet, permisos de administrador y **al menos 22 GB libres**. Ejecuta:

```bash
sudo apt update
sudo apt install xorriso squashfs-tools curl gpgv python3 ca-certificates
sudo ./construir.sh
sha256sum -c AyusOS-Linux-1.3-amd64.iso.sha256
```

Sin argumentos, el script descarga la ISO GNOME actual de Debian 13 en `descargas/`, comprueba su suma SHA-256 y crea `AyusOS-Linux-1.3-amd64.iso` junto al repositorio. Si ya tienes la ISO oficial descargada, puedes reutilizarla:

```bash
sudo ./construir.sh debian-live-13.8.0-amd64-gnome.iso
```

También puedes elegir la ruta de salida:

```bash
sudo ./remaster/crear-iso-debian-gnome.sh debian-live-13.8.0-amd64-gnome.iso AyusOS-Linux-1.3-personalizada-amd64.iso
```

El script monta el sistema de archivos de la ISO en un chroot, instala las aplicaciones de `config/package-lists`, incorpora AiO Debian GUI estable, aplica `config/includes.chroot`, ajusta el idioma y el arranque, y reconstruye la ISO híbrida. Además actualiza tanto `sha256sum.txt` como `md5sum.txt` para que la comprobación de integridad del medio siga funcionando.

La ISO resultante incluye el escritorio GNOME completo de Debian y puede ocupar alrededor de 4 GB. Para probarla desde una memoria USB, utiliza una de **8 GB o más**.

<details>
<summary>Ver la receta histórica de la 1.2</summary>

La versión 1.2 partía de la ISO estable 1.1 y conservaba su escritorio e instalador. El script `remaster/crear-iso-recorrido.sh` se conserva como referencia histórica, pero ya no se mantiene frente al paquete de versión actual y no debe usarse para compilaciones nuevas.

</details>

## El escritorio

| Al iniciar AyusOS | Qué encontrarás |
| --- | --- |
| **Sesión GNOME** | Escritorio GNOME, inicio de sesión con GDM y conexiones de red gestionadas por NetworkManager. |
| **Español de España** | Sesión Live con teclado español, horario de Madrid y Firefox ESR con traducción al español. |
| **Base Debian 13** | Paquetes de Debian estable «trixie» y acceso al componente de firmware para hardware que lo necesita. |
| **Modo Live e instalación** | La ISO parte de Debian Live GNOME, conserva su arranque híbrido y utiliza Calamares con el recorrido de AyusOS en español. |

## AiO Debian GUI

La receta actualiza **AiO Debian GUI** al último DEB estable publicado en su repositorio y comprueba el SHA-256 antes de instalarlo. La compilación se detiene si APT necesita retirar paquetes de la base oficial; puede actualizar dependencias cuando sea necesario para instalar las aplicaciones de AyusOS.

![Vista de mantenimiento de AiO Debian GUI con las opciones de actualización y limpieza](https://raw.githubusercontent.com/julioayusoalende-hue/AIO-Debian-GUI/v1.1.6/docs/capturas/mantenimiento.png)

*Captura del proyecto AiO Debian GUI. La sección de mantenimiento reúne la actualización de paquetes y la limpieza del sistema.*

- **Antes de limpiar**, revisa la simulación de APT para ver qué paquetes propone retirar.
- **Si algo falla**, consulta el diagnóstico de APT y los servicios, o abre el historial de mantenimiento para revisar la ejecución.
- **Antes de cambiar el escritorio**, guarda una copia de los ajustes de GNOME y de los repositorios APT desde Backup.
- **Para automatizar el mantenimiento**, programa las tareas con systemd y consulta su resultado desde la aplicación.

<details>
<summary><strong>Ver la pantalla de copias de seguridad</strong></summary>

![Panel Backup de AiO Debian GUI para copiar y restaurar la configuración](https://raw.githubusercontent.com/julioayusoalende-hue/AIO-Debian-GUI/v1.1.6/docs/capturas/backup.png)

</details>

[Proyecto AiO Debian GUI y guía de uso](https://github.com/julioayusoalende-hue/AIO-Debian-GUI)

## Construir la ISO

Las instrucciones completas están en [Construir AyusOS Linux 1.3 sobre Debian Live GNOME](#construir-ayusos-linux-13-sobre-debian-live-gnome). El script canónico es `remaster/crear-iso-debian-gnome.sh`; `construir.sh` y `remaster/crear-iso-1.3.sh` lo llaman para mantener compatibilidad con las recetas anteriores.

### Probar en GNOME Cajas

1. Crea una máquina virtual desde la ISO, asígnale 4 GB de RAM y arranca la sesión Live.
2. Comprueba el idioma, el teclado y el nombre de la distribución en **Configuración → Sistema → Acerca de**. Busca **AiO Debian GUI** en la vista de aplicaciones y abre su diagnóstico.
3. Para probar la instalación, arranca de nuevo desde la ISO, elige el instalador y selecciona un disco virtual vacío. Expulsa la ISO y verifica que GNOME arranca desde el disco.

### Personalizar la imagen

Las listas de `config/package-lists` definen las aplicaciones adicionales. `config/includes.chroot` contiene el branding, los fondos, las extensiones, Calamares y los servicios; `remaster/release` genera el paquete de identidad y actualización; `remaster/branding` instala los logos del distribuidor. El [script de configuración](config/hooks/live/0900-ayusos.hook.chroot) aplica los últimos ajustes de idioma, escritorio e instalador dentro del chroot.
