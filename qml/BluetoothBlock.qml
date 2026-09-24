// Bluetooth block: adapter/connection state. Click opens a popout to toggle the
// adapter, scan, and connect or forget devices. Hovering shows the connected
// device (or the adapter state). Hidden when the machine has no adapter.
import Quickshell
import Quickshell.Bluetooth
import QtQuick

Item {
    id: bluetooth

    required property Theme theme

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property var connectedDevice: {
        if (!adapter)
            return null;
        var list = adapter.devices.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i];
        }
        return null;
    }
    readonly property string stateName: {
        if (connectedDevice)
            return connectedDevice.name || connectedDevice.address || "Connected";
        if (!adapter)
            return "No adapter";
        return adapter.enabled ? "Bluetooth on" : "Bluetooth off";
    }

    property PopoutState popout: PopoutState {}

    visible: present
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Glyph {
        id: icon

        anchors.centerIn: parent
        theme: bluetooth.theme
        name: "bluetooth"
        color: hover.containsMouse || bluetooth.popout.open ? bluetooth.theme.accent : (bluetooth.connectedDevice ? bluetooth.theme.text : bluetooth.theme.overlay)
    }

    Tooltip {
        id: tip

        theme: bluetooth.theme
        item: bluetooth
        title: bluetooth.stateName
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
        onClicked: bluetooth.popout.activate()
    }

    BluetoothPopout {
        theme: bluetooth.theme
        open: bluetooth.popout.open
        pinned: bluetooth.popout.pinned
        onFocusLost: bluetooth.popout.focusLost()
    }
}
