import QtQuick
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function onActivate() {
        currentSlide = 0
    }

    Timer {
        interval: 8000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    component TourSlide: Slide {
        id: tour

        required property string heading
        required property string explanation
        required property string wallpaper

        Rectangle {
            anchors.fill: parent
            color: "#290811"

            Image {
                anchors.fill: parent
                source: "/usr/share/backgrounds/ayusos/" + tour.wallpaper
                sourceSize.width: 1000
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#b3180911"
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 540)
                spacing: 14

                Text {
                    width: parent.width
                    text: tour.heading
                    color: "#ffffff"
                    font.pixelSize: 27
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: tour.explanation
                    color: "#f9ebef"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    TourSlide {
        heading: qsTr("Bienvenido a AyusOS Linux")
        explanation: qsTr("AyusOS reúne Debian 13 estable y un escritorio GNOME en español.")
        wallpaper: "emblema-oscuro.jpg"
    }

    TourSlide {
        heading: qsTr("Encuentra tus aplicaciones")
        explanation: qsTr("Busca aplicaciones en la vista de Actividades y navega con Google Chrome. AyusOS también incluye Flatpak.")
        wallpaper: "guadarrama-claro.jpg"
    }

    TourSlide {
        heading: qsTr("Mantén el sistema al día")
        explanation: qsTr("AiO Debian GUI permite actualizar paquetes, revisar el estado de APT y consultar el historial de mantenimiento.")
        wallpaper: "matrix-oscuro.jpg"
    }

    TourSlide {
        heading: qsTr("Protege tu configuración")
        explanation: qsTr("Timeshift crea instantáneas del sistema que puedes usar para restaurarlo después de un cambio problemático.")
        wallpaper: "guadarrama-oscuro.jpg"
    }

    TourSlide {
        heading: qsTr("Actualiza AyusOS")
        explanation: qsTr("Abre el Actualizador de AyusOS para comprobar si hay una versión nueva de la distribución.")
        wallpaper: "matrix-claro.jpg"
    }

    TourSlide {
        heading: qsTr("Personaliza el escritorio")
        explanation: qsTr("En Configuración → Apariencia puedes elegir Sierra de Guadarrama, Emblema o Matrix. Cada fondo tiene una variante clara y otra oscura.")
        wallpaper: "emblema-claro.jpg"
    }
}
