// Volume block: shows the default sink's mute state and level, drawing
// headphones when that sink is a headset and a speaker otherwise. Click opens
// the audio popout on hover (short delay) or immediately on click/scroll;
// middle click mutes, scroll adjusts the level.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: volume

    required property Theme theme
    // The bar window. The popout whitelists it in its focus grab so input on
    // the block (scrolling, clicking) is not swallowed by the grab.
    property var anchorWindow: null

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink && sink.audio ? sink.audio : null
    readonly property bool muted: audio ? audio.muted : false
    readonly property int percent: audio ? Math.round(audio.volume * 100) : 0
    readonly property bool silent: !audio || muted || percent === 0
    // PipeWire names a headset through the device icon hint or its node name.
    readonly property bool headphones: {
        var node = sink;
        if (!node)
            return false;
        var properties = node.properties || ({});
        var hint = ((properties["device.icon-name"] || "") + " " + (node.name || "") + " " + (node.description || "")).toLowerCase();
        return hint.indexOf("headphone") >= 0 || hint.indexOf("headset") >= 0;
    }
    readonly property string glyphName: headphones ? (silent ? "headphones-mute" : "headphones-level") : (silent ? "volume-mute" : percent <= 50 ? "volume-low" : "volume")
    readonly property real glyphLevel: silent ? 0 : (percent <= 50 ? 0.5 : 1)
    property PopoutState popout: PopoutState {}

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    // No default sink means no audio session here (e.g. the greeter, which runs
    // outside the user's PipeWire): hide rather than showing a false "muted".
    visible: volume.sink !== null

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            theme: volume.theme
            name: volume.glyphName
            level: volume.glyphLevel
            color: hover.containsMouse || volume.popout.open ? volume.theme.accent : volume.theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: volume.audio ? volume.percent + "%" : "--"
            color: hover.containsMouse || volume.popout.open ? volume.theme.accent : volume.theme.text
            font.family: volume.theme.fontFamily
            font.pixelSize: volume.theme.fontSize
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onContainsMouseChanged: containsMouse ? volume.popout.anchorEntered() : volume.popout.anchorExited()
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                // Mute is a transient action: open, but fade out on mouse-out.
                volume.popout.hoverActivate();
                if (volume.audio)
                    volume.audio.muted = !volume.audio.muted;
            } else {
                // Left/right click pins the popout until focus is lost.
                volume.popout.activate();
            }
        }
        onWheel: event => {
            volume.popout.hoverActivate();
            if (!volume.audio)
                return;
            const delta = (event.angleDelta.y / 120) * 0.05;
            const next = Math.max(0, Math.min(1, volume.audio.volume + delta));
            volume.audio.volume = next;
            volume.audio.muted = next <= 0;
        }
    }

    VolumePopout {
        theme: volume.theme
        headphones: volume.headphones
        anchorWindow: volume.anchorWindow
        open: volume.popout.open
        pinned: volume.popout.pinned
        onHoveredChanged: hovered ? volume.popout.contentEntered() : volume.popout.contentExited()
        onFocusLost: volume.popout.focusLost()
    }
}
