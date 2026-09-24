// Audio popout: output (sink) and input (source) level meters and volume
// sliders for the default devices. The device icon (headphone/speaker/mic) is
// also the mute toggle, drawing the shared mute cross when muted; the sliders
// take the wheel, and taking one to 0 mutes that device.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: popout

    required property Theme theme
    // Whether the default sink is a headset; the owner detects this from
    // PipeWire so the bar block and the popout agree on one answer.
    property bool headphones: false
    // The window that opened us. It is whitelisted with us in the focus grab
    // so mouse input on the bar (scrolling the block) still reaches it; the
    // grab otherwise clears on any event outside the popout.
    property var anchorWindow: null
    // The mixer to open from the cog (e.g. pavucontrol, pavucontrol-qt, kmix).
    // Unset hides the cog rather than offering a launcher that does nothing.
    readonly property string manager: Quickshell.env("QSHELL_AUDIO_MANAGER") || ""

    // The owner opens/closes us (hover-with-delay or click); hover over the
    // popout itself reports back so it stays open while the pointer is inside.
    property bool open: false
    // Pinned (click-opened) popouts close only when focus is lost.
    property bool pinned: false
    signal focusLost()
    readonly property bool hovered: popupHover.hovered

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinkAudio: sink && sink.audio ? sink.audio : null
    readonly property var sourceAudio: source && source.audio ? source.audio : null

    function deviceName(node): string {
        if (!node)
            return "No device";
        return node.description || node.nickname || node.name || "Unknown device";
    }

    function launchManager(): void {
        Quickshell.execDetached(["sh", "-c", manager]);
    }

    // The device-type half of the output icon; muting swaps it for a mute mark
    // in the row, otherwise the level waves sit beside it.
    function outputOn(node): string {
        if (headphones)
            return "headphones-level";
        if (!node || !node.audio)
            return "volume";
        return node.audio.volume <= 0.5 ? "volume-low" : "volume";
    }

    // Level meter colour: Catppuccin green -> yellow -> red, so a meter reads
    // differently from the (blue) sliders. Green covers most of the range, then
    // a short yellow band, then red only near the top.
    function meterColor(level): color {
        var t = Math.max(0, Math.min(1, level));
        var green = Qt.rgba(0.651, 0.890, 0.631, 1);   // a6e3a1
        var yellow = Qt.rgba(0.976, 0.886, 0.686, 1);  // f9e2af
        var red = Qt.rgba(0.953, 0.545, 0.659, 1);     // f38ba8
        if (t < 0.65)
            return green;
        var from = t < 0.9 ? green : yellow;
        var to = t < 0.9 ? yellow : red;
        var k = t < 0.9 ? (t - 0.65) / 0.25 : (t - 0.9) / 0.1;
        return Qt.rgba(from.r + (to.r - from.r) * k, from.g + (to.g - from.g) * k, from.b + (to.b - from.b) * k, 1);
    }

    visible: open
    implicitWidth: 320
    implicitHeight: layout.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-audio"

    anchors {
        top: true
        right: true
    }
    margins.top: 38
    margins.right: 8

    // A click-opened (pinned) popout closes when it loses focus. The bar is
    // whitelisted too so scrolling the block is passed through rather than
    // clearing the grab; opening another block's popout still clears this one.
    HyprlandFocusGrab {
        active: popout.open && popout.pinned
        windows: popout.anchorWindow ? [popout, popout.anchorWindow] : [popout]
        onCleared: popout.focusLost()
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    PwNodePeakMonitor {
        id: sinkPeaks

        node: Pipewire.defaultAudioSink
        enabled: popout.open
    }

    PwNodePeakMonitor {
        id: sourcePeaks

        node: Pipewire.defaultAudioSource
        enabled: popout.open
    }

    component Meter: Column {
        id: meter

        property var monitor
        readonly property int count: monitor && monitor.peaks ? Math.max(1, monitor.peaks.length) : 1

        spacing: 2

        Repeater {
            model: meter.count

            Rectangle {
                required property int index

                width: meter.width
                height: 4
                radius: 2
                color: popout.theme.base

                Rectangle {
                    readonly property real level: Math.min(1, meter.monitor && meter.monitor.peaks ? meter.monitor.peaks[index] : 0)

                    width: parent.width * level
                    height: parent.height
                    radius: 2
                    color: popout.meterColor(level)

                    Behavior on width {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }
    }

    component LevelSlider: Item {
        id: slider

        property real value: 0
        signal moved(real value)

        implicitHeight: 18

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: popout.theme.base
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: track.width * Math.max(0, Math.min(1, slider.value))
            height: 4
            radius: 2
            color: popout.theme.accent
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: track.width * Math.max(0, Math.min(1, slider.value)) - width / 2
            width: 12
            height: 12
            radius: 6
            color: popout.theme.text
        }

        MouseArea {
            anchors.fill: parent

            function setFromX(x) {
                slider.moved(Math.max(0, Math.min(1, x / width)));
            }

            onPressed: mouse => setFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    setFromX(mouse.x);
            }
            onWheel: event => {
                slider.moved(Math.max(0, Math.min(1, slider.value + (event.angleDelta.y / 120) * 0.05)));
            }
        }
    }

    // The device icon doubles as the mute toggle: it shows the device type, or
    // the mute mark when muted, and a click toggles that state.
    component DeviceButton: Glyph {
        id: button

        theme: popout.theme
        property bool muted
        property string onName: "volume"
        property string offName: "volume-mute"
        signal toggled()

        color: hover.containsMouse ? popout.theme.accent : popout.theme.text
        name: muted ? offName : onName

        MouseArea {
            id: hover

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: button.toggled()
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
                        text: "Audio"
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
                }

                Text {
                    text: "Output"
                    color: popout.theme.subtext
                    font.family: popout.theme.fontFamily
                    font.pixelSize: popout.theme.fontSizeTiny
                }

                Row {
                    width: parent.width
                    spacing: 8

                    DeviceButton {
                        id: muteOut

                        anchors.verticalCenter: parent.verticalCenter
                        level: popout.sinkAudio ? popout.sinkAudio.volume : 0
                        muted: popout.sinkAudio ? popout.sinkAudio.muted : false
                        onName: popout.outputOn(popout.sink)
                        offName: popout.headphones ? "headphones-mute" : "volume-mute"
                        onToggled: if (popout.sinkAudio)
                            popout.sinkAudio.muted = !popout.sinkAudio.muted
                    }

                    Text {
                        width: parent.width - muteOut.width - 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: popout.deviceName(popout.sink)
                        color: popout.theme.text
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeSmall
                    }
                }

                Meter {
                    width: parent.width
                    monitor: sinkPeaks
                }

                Row {
                    width: parent.width
                    spacing: 10

                    LevelSlider {
                        width: parent.width - 40
                        value: popout.sinkAudio ? popout.sinkAudio.volume : 0
                        onMoved: value => {
                            if (popout.sinkAudio) {
                                popout.sinkAudio.volume = value;
                                // Zero is silence: mute so the icon agrees.
                                popout.sinkAudio.muted = value <= 0;
                            }
                        }
                    }

                    Text {
                        width: 30
                        horizontalAlignment: Text.AlignRight
                        color: popout.theme.text
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeSmall
                        text: (popout.sinkAudio ? Math.round(popout.sinkAudio.volume * 100) : 0) + "%"
                    }
                }

                Text {
                    text: "Input"
                    color: popout.theme.subtext
                    font.family: popout.theme.fontFamily
                    font.pixelSize: popout.theme.fontSizeTiny
                }

                Row {
                    width: parent.width
                    spacing: 8

                    DeviceButton {
                        id: muteIn

                        anchors.verticalCenter: parent.verticalCenter
                        level: popout.sourceAudio ? popout.sourceAudio.volume : 0
                        onName: "mic"
                        offName: "mic-off"
                        muted: popout.sourceAudio ? popout.sourceAudio.muted : false
                        onToggled: if (popout.sourceAudio)
                            popout.sourceAudio.muted = !popout.sourceAudio.muted
                    }

                    Text {
                        width: parent.width - muteIn.width - 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: popout.deviceName(popout.source)
                        color: popout.theme.text
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeSmall
                    }
                }

                Meter {
                    width: parent.width
                    monitor: sourcePeaks
                }

                Row {
                    width: parent.width
                    spacing: 10

                    LevelSlider {
                        width: parent.width - 40
                        value: popout.sourceAudio ? popout.sourceAudio.volume : 0
                        onMoved: value => {
                            if (popout.sourceAudio) {
                                popout.sourceAudio.volume = value;
                                popout.sourceAudio.muted = value <= 0;
                            }
                        }
                    }

                    Text {
                        width: 30
                        horizontalAlignment: Text.AlignRight
                        color: popout.theme.text
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeSmall
                        text: (popout.sourceAudio ? Math.round(popout.sourceAudio.volume * 100) : 0) + "%"
                    }
                }
            }
        }
    }

    // Hover tracking only; does not consume presses, so the sliders still work.
    Item {
        anchors.fill: parent

        HoverHandler {
            id: popupHover
        }
    }
}
