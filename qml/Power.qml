// Power block: opens the session menu.
import QtQuick

Item {
    id: power

    required property Theme theme

    signal activated()

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Glyph {
        id: icon

        anchors.centerIn: parent
        theme: power.theme
        name: "power"
        color: hover.containsMouse ? power.theme.accent : power.theme.text
    }

    MouseArea {
        id: hover

        // Extend to the screen's top-right corner so there is no dead zone.
        anchors {
            fill: parent
            rightMargin: -8
            margins: -4
        }
        hoverEnabled: true
        onClicked: power.activated()
    }
}
