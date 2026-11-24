<div align="center">

<img src="https://raw.githubusercontent.com/julioayusoalende-hue/AIO-Debian-GUI/v1.1.6/package/usr/share/aio-debian-gui/ayusos-logo.png" width="144" alt="Logotipo de AyusOS Linux">

# AyusOS Linux

**Debian 13 estable · GNOME en español · AiO Debian GUI**

Un escritorio para trabajar y una herramienta gráfica para mantenerlo. Arranca AyusOS desde un USB, explora GNOME y decide cuándo instalarlo.

[El escritorio](#el-escritorio) · [AiO Debian GUI](#aio-debian-gui) · [Construir la ISO](#construir-la-iso)

</div>

---

**Candidata corregida de AyusOS 1.3 para amd64.** Se remasteriza la ISO oficial 1.2 en lugar de generar un sistema desde cero. La candidata no sustituye la descarga pública hasta que se compruebe su funcionamiento.

## Construir AyusOS Linux 1.2

La versión 1.2 parte de la ISO estable 1.1 con el icono del actualizador. Conserva Calamares y añade el recorrido durante la instalación y seis fondos claros y oscuros. La receta comprueba el SHA-256 de la ISO base antes de reconstruirla.

```bash
sudo apt install xorriso squashfs-tools
sudo ./remaster/crear-iso-recorrido.sh AyusOS-Linux-1.1-icono-actualizador-amd64.iso AyusOS-Linux-1.2-amd64.iso
sha256sum -c AyusOS-Linux-1.2-amd64.iso.sha256
```

## El escritorio

| Al iniciar AyusOS | Qué encontrarás |
| --- | --- |
| **Sesión GNOME** | Escritorio GNOME, inicio de sesión con GDM y conexiones de red gestionadas por NetworkManager. |
| **Español de España** | Sesión Live con teclado español, horario de Madrid y Firefox ESR con traducción al español. |
| **Base Debian 13** | Paquetes de Debian estable «trixie» y acceso al componente de firmware para hardware que lo necesita. |
| **Modo Live e instalación** | La candidata conserva el arranque híbrido, Calamares y su recorrido en español tal como venían en AyusOS 1.2. |

## AiO Debian GUI

La receta de la candidata actualiza **AiO Debian GUI** al último DEB estable publicado en su repositorio y comprueba el SHA-256 antes de instalarlo. La compilación se detiene si APT necesita quitar o actualizar otros paquetes de la base. Solo se permiten dependencias nuevas cuando son necesarias.

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

Usa la [ISO oficial 1.2](https://github.com/julioayusoalende-hue/AyusOS-Linux/releases/tag/v1.2), no la receta histórica `construir.sh`. El remaster verifica su SHA-256 y conserva Calamares, las personalizaciones y la selección de aplicaciones, salvo Kitty, que se sustituye por Terminal de GNOME en el escritorio y en el actualizador. Añade los dos fondos sin quitar los existentes ni cambiar el de bloqueo. La pantalla de inicio de sesión de GDM toma el mismo acento predeterminado que el escritorio (rojo).

```bash
sudo apt install curl ca-certificates xorriso squashfs-tools
sudo bash remaster/crear-iso-1.3.sh AyusOS-Linux-1.2-amd64.iso AyusOS-Linux-1.3-candidata-amd64.iso
sha256sum -c AyusOS-Linux-1.3-candidata-amd64.iso.sha256
```

### Probar en GNOME Cajas

1. Crea una máquina virtual desde la ISO, asígnale 4 GB de RAM y arranca la sesión Live.
2. Comprueba el idioma, el teclado y el nombre de la distribución en **Configuración → Sistema → Acerca de**. Busca **AiO Debian GUI** en la vista de aplicaciones y abre su diagnóstico.
3. Para probar la instalación, arranca de nuevo desde la ISO, elige el instalador y selecciona un disco virtual vacío. Expulsa la ISO y verifica que GNOME arranca desde el disco.

### Personalizar la imagen

La [lista de paquetes](config/package-lists/escritorio.list.chroot) define las aplicaciones del escritorio. El [script de configuración](config/hooks/live/0900-ayusos.hook.chroot) establece la identidad de AyusOS y el idioma.
