// Bluetooth popout: adapter toggle, scanning, and the device list. A device
// connects, pairs or disconnects only via the icon action that appears on hover
// (never by clicking the row); right-click forgets a paired device. Opened by
// the Bluetooth block.
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: popout

    required property Theme theme

    property bool open: false
    property bool pinned: false
    signal focusLost()

    readonly property var adapter: Bluetooth.defaultAdapter
    // Connected first, then paired, then by name.
    readonly property var devices: {
        if (!adapter)
            return [];
        return adapter.devices.values.slice().sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            var an = nameOf(a).toLowerCase();
            var bn = nameOf(b).toLowerCase();
            return an < bn ? -1 : an > bn ? 1 : 0;
        });
    }

    function nameOf(device): string {
        return device.name || device.deviceName || device.address || "Unknown device";
    }

    function glyphOf(device): string {
        var icon = (device.icon || "").toLowerCase();
        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0 || icon.indexOf("audio") >= 0 || icon.indexOf("speaker") >= 0)
            return "headphones";
        if (icon.indexOf("keyboard") >= 0)
            return "keyboard";
        if (icon.indexOf("mouse") >= 0)
            return "mouse";
        if (icon.indexOf("phone") >= 0)
            return "phone";
        return "bluetooth";
    }

    function statusOf(device): string {
        if (device.connected)
            return device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "Connected";
        return device.paired ? "Paired" : "";
    }

    function actionOf(device): string {
        return device.connected ? "unlink" : "link";
    }

    function activateDevice(device): void {
        if (device.connected)
            device.disconnect();
        else if (!device.paired)
            device.pair();
        else
            device.connect();
    }

    visible: open
    implicitWidth: 300
    implicitHeight: layout.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bluetooth"

    anchors {
        top: true
        right: true
    }
    margins.top: 38
    margins.right: 8

    HyprlandFocusGrab {
        active: popout.open && popout.pinned
        windows: [popout]
        onCleared: popout.focusLost()
    }

    component Action: Text {
        id: action

        signal triggered()

        color: actionHover.containsMouse ? popout.theme.accent : popout.theme.subtext
        font.family: popout.theme.fontFamily
        font.pixelSize: popout.theme.fontSizeSmall

        MouseArea {
            id: actionHover

            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            onClicked: action.triggered()
        }
    }

    component IconAction: Glyph {
        id: action

        theme: popout.theme
        signal triggered()

        color: actionHover.containsMouse ? popout.theme.accent : popout.theme.subtext

        MouseArea {
            id: actionHover

            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            onClicked: action.triggered()
        }
    }

    component DeviceRow: Rectangle {
        id: row

        required property var device

        implicitHeight: 30
        color: "transparent"

        HoverHandler {
            id: rowHover
        }

        Row {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 8
                rightMargin: 8
            }
            spacing: 8

            Glyph {
                id: glyph

                anchors.verticalCenter: parent.verticalCenter
                theme: popout.theme
                name: popout.glyphOf(row.device)
                color: row.device.connected || rowHover.hovered ? popout.theme.accent : popout.theme.text
            }

            Text {
                width: parent.width - glyph.width - status.width - 24
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: popout.nameOf(row.device)
                color: rowHover.hovered ? popout.theme.accent : popout.theme.text
                font.family: popout.theme.fontFamily
                font.pixelSize: popout.theme.fontSizeSmall
            }

            Text {
                id: status

                anchors.verticalCenter: parent.verticalCenter
                text: popout.statusOf(row.device)
                color: row.device.connected ? popout.theme.accent : popout.theme.overlay
                font.family: popout.theme.fontFamily
                font.pixelSize: popout.theme.fontSizeTiny
            }
        }

        // Connect / disconnect, only while the row is hovered.
        IconAction {
            id: rowAction

            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            opacity: rowHover.hovered ? 1 : 0
            enabled: rowHover.hovered
            name: popout.actionOf(row.device)
            onTriggered: popout.activateDevice(row.device)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: if (row.device.paired)
                row.device.forget()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: popout.theme.radius
        color: popout.theme.surface
        border.width: 1
        border.color: popout.theme.border

        Item {
            anchors.fill: parent

            Column {
                id: layout

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        id: heading

                        anchors.verticalCenter: parent.verticalCenter
                        text: "Bluetooth"
                        color: popout.theme.subtext
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeTiny
                    }

                    Item {
                        width: Math.max(0, parent.width - heading.width - scanAction.width - adapterToggle.width - parent.spacing * 3)
                        height: 1
                    }

                    Action {
                        id: scanAction

                        visible: popout.adapter !== null && popout.adapter.enabled
                        anchors.verticalCenter: parent.verticalCenter
                        text: popout.adapter && popout.adapter.discovering ? "Stop" : "Scan"
                        onTriggered: if (popout.adapter)
                            popout.adapter.discovering = !popout.adapter.discovering
                    }

                    Toggle {
                        id: adapterToggle

                        anchors.verticalCenter: parent.verticalCenter
                        theme: popout.theme
                        on: popout.adapter !== null && popout.adapter.enabled
                        onToggled: if (popout.adapter)
                            popout.adapter.enabled = !popout.adapter.enabled
                    }
                }

                Text {
                    visible: popout.adapter === null || !popout.adapter.enabled
                    text: "Bluetooth is off"
                    color: popout.theme.overlay
                    font.family: popout.theme.fontFamily
                    font.pixelSize: popout.theme.fontSizeSmall
                }

                Repeater {
                    model: popout.adapter !== null && popout.adapter.enabled ? popout.devices : []

                    DeviceRow {
                        required property var modelData

                        width: layout.width
                        device: modelData
                    }
                }

                Text {
                    visible: popout.adapter !== null && popout.adapter.enabled && popout.devices.length === 0
                    text: "No devices"
                    color: popout.theme.overlay
                    font.family: popout.theme.fontFamily
                    font.pixelSize: popout.theme.fontSizeSmall
                }
            }
        }
    }
}
