// The session top bar: a Hyprland layer-shell surface. The translucent
// background lets Hyprland's layer blur show as frosted glass (the
// `quickshell-.*` namespace is matched by the compositor's layer rule).
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: bar

    required property Theme theme

    // The greeter has no workspaces to show; the session shell does.
    property bool showWorkspaces: true

    // Forwarded from the power block; the shell root opens the session menu.
    signal powerRequested()

    // Width of everything to the tray's right, so the tray can cap itself
    // without colliding with the clock.
    readonly property real rightFixedWidth: media.implicitWidth + network.implicitWidth + bluetooth.implicitWidth + brightness.implicitWidth + volume.implicitWidth + battery.implicitWidth + power.implicitWidth + rightCluster.spacing * 7

    // The clock opens the drop-down calendar (click to pin, focus-loss closes).
    property PopoutState clockPopout: PopoutState {}

    // On a PanelWindow these anchors are booleans meaning "attach to this screen
    // edge", not QML item anchors. exclusiveZone reserves the space so maximised
    // windows don't slide underneath.
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 32
    exclusiveZone: 32
    color: theme.bar
    WlrLayershell.namespace: "quickshell-bar"

    Workspaces {
        id: workspaces

        visible: bar.showWorkspaces
        theme: bar.theme
        screen: bar.screen
        height: bar.implicitHeight
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
    }

    Row {
        id: rightCluster

        anchors {
            right: parent.right
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        height: bar.implicitHeight
        spacing: 12

        // Keep the tray clear of the centred clock. `bar.width` is the screen
        // width; the clock is centred, so half its width plus a gap is reserved.
        Tray {
            theme: bar.theme
            height: bar.implicitHeight
            maxWidth: Math.max(0, bar.width / 2 - clock.width / 2 - bar.rightFixedWidth - 8 - 16)
        }

        // Now-playing, immediately right of the tray icons.
        Media {
            id: media

            theme: bar.theme
            height: bar.implicitHeight
        }

        NetworkBlock {
            id: network

            theme: bar.theme
            height: bar.implicitHeight
        }

        BluetoothBlock {
            id: bluetooth

            theme: bar.theme
            height: bar.implicitHeight
        }

        BrightnessBlock {
            id: brightness

            theme: bar.theme
            height: bar.implicitHeight
            anchorWindow: bar
        }

        Volume {
            id: volume

            theme: bar.theme
            height: bar.implicitHeight
            anchorWindow: bar
        }

        Battery {
            id: battery

            theme: bar.theme
            height: bar.implicitHeight
        }

        Power {
            id: power

            theme: bar.theme
            height: bar.implicitHeight
            onActivated: bar.powerRequested()
        }
    }

    Text {
        id: clock

        anchors.centerIn: parent
        color: theme.text
        font.family: theme.fontFamily
        font.pixelSize: theme.fontSize
        text: Qt.formatDateTime(new Date(), "ddd yyyy-MM-dd HH:mm:ss")

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd yyyy-MM-dd HH:mm:ss")
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: bar.clockPopout.open ? bar.clockPopout.close() : bar.clockPopout.activate()
        }
    }

    Calendar {
        theme: bar.theme
        // Clock centre in bar (screen) coordinates; the clock is centred, so
        // this is the screen centre. `mapToItem(null, …)` returns 0 for these
        // layer surfaces, hence the direct arithmetic.
        anchorX: clock.x + clock.width / 2
        open: bar.clockPopout.open
        pinned: bar.clockPopout.pinned
        onHoveredChanged: hovered ? bar.clockPopout.contentEntered() : bar.clockPopout.contentExited()
        onFocusLost: bar.clockPopout.focusLost()
        onDismissRequested: bar.clockPopout.close()
    }
}
