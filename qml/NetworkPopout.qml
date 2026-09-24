// Network popout: wifi toggle, the wired link, the wifi network list, and a
// configurable manager launcher. A network connects or disconnects only via the
// icon action that appears on hover (never by clicking the row), so a stray
// click cannot drop the connection. Scanning runs only while the popout is open.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: popout

    required property Theme theme

    property bool open: false
    property bool pinned: false
    signal focusLost()

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }
    readonly property var wiredDevice: {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wired)
                return devices[i];
        }
        return null;
    }
    // Connected first, then strongest signal.
    readonly property var networks: {
        if (wifiDevice === null)
            return [];
        return wifiDevice.networks.values.slice().sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
    }
    // The network manager GUI to launch, e.g. nm-connection-editor or nmtui.
    // Unset hides the cog rather than offering a launcher that does nothing.
    readonly property string manager: Quickshell.env("QSHELL_NETWORK_MANAGER") || ""

    // The secured, unsaved network awaiting a password.
    property var pendingNetwork: null

    function securityOpen(network): bool {
        return network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe;
    }

    function statusOf(network): string {
        if (network.connected)
            return "Connected";
        if (network.known)
            return "Saved";
        return Math.round(network.signalStrength * 100) + "%";
    }

    function activate(network): void {
        if (network.connected) {
            network.disconnect();
        } else if (network.known || securityOpen(network)) {
            pendingNetwork = null;
            network.connect();
        } else {
            pendingNetwork = network;
        }
    }

    function submitPsk(text): void {
        if (pendingNetwork !== null && text !== "") {
            pendingNetwork.connectWithPsk(text);
            pendingNetwork = null;
        }
    }

    function launchManager(): void {
        Quickshell.execDetached(["sh", "-c", manager]);
    }

    visible: open
    implicitWidth: 320
    implicitHeight: layout.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-network"

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

    // Scan only while the popout is up.
    Binding {
        target: popout.wifiDevice
        property: "scannerEnabled"
        value: popout.open
        when: popout.wifiDevice !== null
    }

    onOpenChanged: if (!open)
        pendingNetwork = null

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

    component NetworkRow: Rectangle {
        id: row

        required property var network

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

            Item {
                id: glyph

                width: popout.theme.fontSize
                height: width
                anchors.verticalCenter: parent.verticalCenter

                Glyph {
                    anchors.fill: parent
                    theme: popout.theme
                    name: "wifi"
                    level: row.network.signalStrength
                    color: row.network.connected ? popout.theme.accent : (rowHover.hovered ? popout.theme.accent : popout.theme.text)
                }
            }

            Text {
                width: parent.width - glyph.width - lock.width - status.width - 24
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.network.name || "Hidden network"
                color: rowHover.hovered ? popout.theme.accent : popout.theme.text
                font.family: popout.theme.fontFamily
                font.pixelSize: popout.theme.fontSizeSmall
            }

            Glyph {
                id: lock

                anchors.verticalCenter: parent.verticalCenter
                visible: !popout.securityOpen(row.network)
                theme: popout.theme
                name: "lock"
                size: popout.theme.fontSizeTiny
                color: popout.theme.overlay
            }

            Text {
                id: status

                anchors.verticalCenter: parent.verticalCenter
                text: popout.statusOf(row.network)
                color: row.network.connected ? popout.theme.accent : popout.theme.overlay
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
            name: row.network.connected ? "unlink" : "link"
            onTriggered: popout.activate(row.network)
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

                RowLayout {
                    width: parent.width
                    spacing: 8

                    Text {
                        id: heading

                        Layout.alignment: Qt.AlignVCenter
                        text: "Network"
                        color: popout.theme.subtext
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeTiny
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                    }

                    IconAction {
                        id: managerAction

                        Layout.alignment: Qt.AlignVCenter
                        visible: popout.manager !== ""
                        name: "gear"
                        onTriggered: popout.launchManager()
                    }

                    Text {
                        id: wifiLabel

                        Layout.alignment: Qt.AlignVCenter
                        visible: popout.wifiDevice !== null
                        text: "Wi-Fi"
                        color: popout.theme.subtext
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeTiny
                    }

                    Toggle {
                        id: wifiToggle

                        Layout.alignment: Qt.AlignVCenter
                        visible: popout.wifiDevice !== null
                        theme: popout.theme
                        on: Networking.wifiEnabled
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }

                Row {
                    visible: popout.wiredDevice !== null && popout.wiredDevice.connected
                    width: parent.width
                    spacing: 8

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        theme: popout.theme
                        name: "ethernet"
                        color: popout.theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: popout.wiredDevice && popout.wiredDevice.name ? popout.wiredDevice.name : "Wired"
                        color: popout.theme.text
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeSmall
                    }
                }

                Text {
                    visible: popout.wifiDevice !== null && !Networking.wifiEnabled
                    text: "Wi-Fi is off"
                    color: popout.theme.overlay
                    font.family: popout.theme.fontFamily
                    font.pixelSize: popout.theme.fontSizeSmall
                }

                Repeater {
                    model: Networking.wifiEnabled ? popout.networks : []

                    NetworkRow {
                        required property var modelData

                        width: layout.width
                        network: modelData
                    }
                }

                Item {
                    visible: popout.pendingNetwork !== null
                    width: parent.width
                    height: 30

                    Rectangle {
                        anchors.fill: parent
                        radius: popout.theme.itemRadius
                        color: popout.theme.base
                        border.width: 1
                        border.color: popout.theme.border
                    }

                    TextInput {
                        id: pskInput

                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        color: popout.theme.text
                        selectionColor: popout.theme.accent
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeSmall
                        echoMode: TextInput.Password
                        focus: popout.pendingNetwork !== null
                        onAccepted: {
                            popout.submitPsk(text);
                            text = "";
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pskInput.text === ""
                            text: "Password for " + (popout.pendingNetwork ? popout.pendingNetwork.name : "")
                            color: popout.theme.overlay
                            font.family: popout.theme.fontFamily
                            font.pixelSize: popout.theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }
}
