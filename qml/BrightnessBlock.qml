// Brightness block: the backlight level via brightnessctl, opening a popout
// with a slider (and the power-profile switcher). Hidden when the machine has
// no backlight. Scroll adjusts by 5%.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: brightness

    required property Theme theme
    // The bar window, passed through to the popout's focus grab.
    property var anchorWindow: null

    property int percent: 0
    property bool available: false

    property PopoutState popout: PopoutState {}

    function refresh(): void {
        readProcess.running = true;
    }

    function setPercent(value): void {
        var clamped = Math.max(1, Math.min(100, Math.round(value)));
        setProcess.command = ["sh", "-c", "brightnessctl -c backlight s " + clamped + "% 2>/dev/null || true"];
        setProcess.running = true;
        percent = clamped; // optimistic; the poll confirms it
    }

    visible: available
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Process {
        id: readProcess

        command: ["sh", "-c", "brightnessctl -c backlight -m 2>/dev/null | head -n1 || true"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var parts = text.trim().split(",");
                var pct = parts.length >= 4 ? parseInt(parts[3], 10) : NaN;
                if (isNaN(pct)) {
                    brightness.available = false;
                } else {
                    brightness.available = true;
                    brightness.percent = pct;
                }
            }
        }
    }

    Process {
        id: setProcess

        command: ["true"]
    }

    // The kernel reports every backlight change as a udev event (sysfs writes
    // and firmware hotkeys alike).
    Process {
        id: watchProcess

        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        running: brightness.available
        stdout: SplitParser {
            onRead: data => refreshTimer.restart()
        }
    }

    // Key repeat arrives as a burst of events; collapse them into one read.
    Timer {
        id: refreshTimer

        interval: 60
        onTriggered: brightness.refresh()
    }

    Component.onCompleted: refresh()

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            theme: brightness.theme
            name: "brightness"
            color: hover.containsMouse || brightness.popout.open ? brightness.theme.accent : brightness.theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: brightness.percent + "%"
            color: hover.containsMouse || brightness.popout.open ? brightness.theme.accent : brightness.theme.text
            font.family: brightness.theme.fontFamily
            font.pixelSize: brightness.theme.fontSize
        }
    }

    Tooltip {
        id: tip

        theme: brightness.theme
        item: brightness
        title: "Brightness " + brightness.percent + "%"
    }

    Timer {
        id: tipTimer

        interval: 600
        onTriggered: if (hover.containsMouse) tip.open = true
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onContainsMouseChanged: {
            if (containsMouse) {
                tipTimer.restart();
            } else {
                tipTimer.stop();
                tip.open = false;
            }
        }
        onClicked: brightness.popout.activate()
        onWheel: event => {
            if (event.angleDelta.y > 0)
                brightness.setPercent(brightness.percent + 5);
            else if (event.angleDelta.y < 0)
                brightness.setPercent(brightness.percent - 5);
        }
    }

    BrightnessPopout {
        theme: brightness.theme
        anchorWindow: brightness.anchorWindow
        open: brightness.popout.open
        pinned: brightness.popout.pinned
        percent: brightness.percent
        onFocusLost: brightness.popout.focusLost()
        onSetPercent: value => brightness.setPercent(value)
    }
}
