// Battery block: level from UPower, drawn with the hand-drawn Glyph set plus
// percent. A charging bolt sits beside the battery. Hidden with no battery.
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Item {
    id: battery

    required property Theme theme

    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.isLaptopBattery
    readonly property int percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: device !== null && [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(device.state)
    readonly property color levelColor: percent <= 20 ? theme.danger : theme.text

    visible: present
    implicitWidth: row.implicitWidth

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                theme: battery.theme
                name: "battery"
                level: battery.percent / 100
                color: battery.levelColor
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: battery.charging
                theme: battery.theme
                name: "flash"
                size: battery.theme.fontSizeSmall
                color: battery.levelColor
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: battery.percent + "%"
            color: battery.levelColor
            font.family: battery.theme.fontFamily
            font.pixelSize: battery.theme.fontSize
        }
    }
}
