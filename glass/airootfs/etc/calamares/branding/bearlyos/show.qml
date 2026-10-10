import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide()
    }

    Timer {
        id: advanceTimer
        interval: 6000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0b0b0e" }
        Image {
            id: bear
            source: "logo.png"
            width: 200; height: 200
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 50
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: bear.bottom
            anchors.topMargin: 26
            text: "BearlyOS Glass"
            color: "#f4f4f6"
            font.pixelSize: 38
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: bear.bottom
            anchors.topMargin: 84
            text: "Oprichter: Luka Biart"
            color: "#F4A63B"
            font.pixelSize: 22
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0b0b0e" }
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: "Je werkplek wordt ingericht…\n\nHyprland · Brave · security-tools · Claude Code"
            color: "#f4f4f6"
            font.pixelSize: 24
            lineHeight: 1.3
        }
    }
}
