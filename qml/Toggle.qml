// Small on/off switch, used by the network and bluetooth popouts.
import QtQuick

Item {
    id: toggle

    required property Theme theme
    property bool on: false
    signal toggled()

    implicitWidth: 36
    implicitHeight: 18

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: toggle.on ? toggle.theme.accent : toggle.theme.surfaceAlt

        Rectangle {
            width: parent.height - 4
            height: width
            radius: width / 2
            y: 2
            x: toggle.on ? parent.width - width - 2 : 2
            color: toggle.on ? toggle.theme.base : toggle.theme.text

            Behavior on x {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        onClicked: toggle.toggled()
    }
}
