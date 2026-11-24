<div align="center">

<img src="https://raw.githubusercontent.com/julioayusoalende-hue/AIO-Debian-GUI/v1.2.0/package/usr/share/aio-debian-gui/ayusos-logo.png" width="144" alt="Logotipo de AyusOS Linux">

# AyusOS Linux

**Debian 13 estable · GNOME en español · AiO Debian GUI**

Un escritorio para trabajar y una herramienta gráfica para mantenerlo. Arranca AyusOS desde un USB, explora GNOME y decide cuándo instalarlo.

[El escritorio](#el-escritorio) · [AiO Debian GUI](#aio-debian-gui) · [Construir la ISO](#construir-la-iso)

</div>

---

**Edición preliminar 0.2 para amd64.** Este repositorio contiene las fuentes para generar la imagen Live. La compilación completa y las pruebas de arranque e instalación están pendientes.

## El escritorio

| Al iniciar AyusOS | Qué encontrarás |
| --- | --- |
| **Sesión GNOME** | Escritorio GNOME, inicio de sesión con GDM y conexiones de red gestionadas por NetworkManager. |
| **Español de España** | Sesión Live con teclado español, horario de Madrid y Firefox ESR con traducción al español. |
| **Base Debian 13** | Paquetes de Debian estable «trixie» y acceso al componente de firmware para hardware que lo necesita. |
| **Modo Live e instalación** | La configuración genera una ISO híbrida para PC Intel y AMD de 64 bits, con instalador de Debian en el menú de arranque. |

## AiO Debian GUI

La receta integra **AiO Debian GUI** como paquete DEB nativo. En cada compilación, el script descarga la última versión estable publicada, comprueba su SHA-256 (SHA256SUMS de la release) y la incorpora al sistema Live. La aplicación reconoce AyusOS y utiliza el icono de la distribución en su interfaz.

![Vista de mantenimiento de AiO Debian GUI con las opciones de actualización y limpieza](https://raw.githubusercontent.com/julioayusoalende-hue/AIO-Debian-GUI/v1.2.0/docs/capturas/mantenimiento.png)

*Captura del proyecto AiO Debian GUI. La sección de mantenimiento reúne la actualización de paquetes y la limpieza del sistema.*

- **Antes de limpiar**, revisa la simulación de APT para ver qué paquetes propone retirar.
- **Si algo falla**, consulta el diagnóstico de APT y los servicios, o abre el historial de mantenimiento para revisar la ejecución.
- **Antes de cambiar el escritorio**, guarda una copia de los ajustes de GNOME y de los repositorios APT desde Backup.
- **Para automatizar el mantenimiento**, programa las tareas con systemd y consulta su resultado desde la aplicación.

<details>
<summary><strong>Ver la pantalla de copias de seguridad</strong></summary>

![Panel Backup de AiO Debian GUI para copiar y restaurar la configuración](https://raw.githubusercontent.com/julioayusoalende-hue/AIO-Debian-GUI/v1.2.0/docs/capturas/backup.png)

</details>

[Proyecto AiO Debian GUI y guía de uso](https://github.com/julioayusoalende-hue/AIO-Debian-GUI)

## Construir la ISO

En Debian 13 amd64, con conexión a Internet y espacio para el sistema descomprimido y la imagen, ejecuta:

```bash
sudo apt update
sudo apt install git live-build curl ca-certificates
git clone https://github.com/julioayusoalende-hue/AyusOS-Linux.git
cd AyusOS-Linux
sudo ./construir.sh
sha256sum -c AyusOS-Linux-0.2-amd64.iso.sha256
```

La imagen **AyusOS-Linux-0.2-amd64.iso** queda junto al script. Cada compilación utiliza su propio directorio `compilacion.*`. Si se interrumpe, entra en ese directorio y ejecuta `sudo lb clean --purge` antes de eliminarlo.

### Probar en GNOME Cajas

1. Crea una máquina virtual desde la ISO, asígnale 4 GB de RAM y arranca la sesión Live.
2. Comprueba el idioma, el teclado y el nombre de la distribución en **Configuración → Sistema → Acerca de**. Busca **AiO Debian GUI** en la vista de aplicaciones y abre su diagnóstico.
3. Para probar la instalación, arranca de nuevo desde la ISO, elige el instalador y selecciona un disco virtual vacío. Expulsa la ISO y verifica que GNOME arranca desde el disco.

### Personalizar la imagen

La [lista de paquetes](config/package-lists/escritorio.list.chroot) define las aplicaciones del escritorio. El [script de configuración](config/hooks/live/0900-ayusos.hook.chroot) establece la identidad de AyusOS y el idioma.
