// Network block: wired/wifi state. Click opens a popout to manage connections;
// hovering shows the current connection as a tooltip. Hidden when the machine
// has no network devices.
import Quickshell
import Quickshell.Networking
import QtQuick

Item {
    id: network

    required property Theme theme

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
    readonly property bool present: devices.length > 0
    readonly property bool online: (wiredDevice !== null && wiredDevice.connected) || (wifiDevice !== null && wifiDevice.connected)
    readonly property bool wired: wiredDevice !== null && wiredDevice.connected
    readonly property var connectedNetwork: {
        if (wifiDevice === null)
            return null;
        var list = wifiDevice.networks.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i];
        }
        return null;
    }
    readonly property string connectionName: {
        if (connectedNetwork !== null)
            return connectedNetwork.name;
        if (wired)
            return "Wired";
        return wifiDevice !== null && !Networking.wifiEnabled ? "Wi-Fi off" : "Disconnected";
    }

    property PopoutState popout: PopoutState {}

    visible: present
    implicitWidth: wired ? ethernet.implicitWidth : wifiIcon.implicitWidth
    implicitHeight: Math.max(wifiIcon.implicitHeight, ethernet.implicitHeight)

    Glyph {
        id: wifiIcon

        anchors.centerIn: parent
        visible: !network.wired
        theme: network.theme
        name: "wifi"
        level: network.connectedNetwork !== null ? network.connectedNetwork.signalStrength : 0
        color: hover.containsMouse || network.popout.open ? network.theme.accent : (network.online ? network.theme.text : network.theme.overlay)
    }

    Glyph {
        id: ethernet

        anchors.centerIn: parent
        visible: network.wired
        theme: network.theme
        name: "ethernet"
        color: hover.containsMouse || network.popout.open ? network.theme.accent : network.theme.text
    }

    Tooltip {
        id: tip

        theme: network.theme
        item: network
        title: network.connectionName
    }

    Timer {
        id: tipTimer

        interval: 600
        onTriggered: if (hover.containsMouse) tip.open = true
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onContainsMouseChanged: {
            if (containsMouse)
                tipTimer.restart();
            else {
                tipTimer.stop();
                tip.open = false;
            }
        }
        onClicked: network.popout.activate()
    }

    NetworkPopout {
        theme: network.theme
        open: network.popout.open
        pinned: network.popout.pinned
        onFocusLost: network.popout.focusLost()
    }
}
