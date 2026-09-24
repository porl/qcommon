// Brightness popout: a backlight slider, and the power-profile switcher when
// power-profiles-daemon is available (detected via its CLI). Opened by the
// Brightness block; hover/pin behaviour comes from the shared PopoutState.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: popout

    required property Theme theme
    // The bar window, whitelisted in the focus grab so scrolling the block
    // still reaches it while the popout is pinned.
    property var anchorWindow: null

    property bool open: false
    property bool pinned: false
    // 0-100.
    property int percent: 0
    signal focusLost()
    signal setPercent(real value)

    // power-profiles-daemon is not part of the fleet; hide the switcher unless
    // its CLI actually works here.
    property bool profilesAvailable: false

    visible: open
    implicitWidth: 300
    implicitHeight: layout.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-brightness"

    anchors {
        top: true
        right: true
    }
    margins.top: 38
    margins.right: 8

    HyprlandFocusGrab {
        active: popout.open && popout.pinned
        windows: popout.anchorWindow ? [popout, popout.anchorWindow] : [popout]
        onCleared: popout.focusLost()
    }

    Process {
        id: ppdCheck

        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        running: true
        onExited: exitCode => {
            popout.profilesAvailable = exitCode === 0;
        }
    }

    component ProfileButton: Glyph {
        id: button

        theme: popout.theme
        required property int profile

        readonly property bool current: PowerProfiles.profile === button.profile

        color: current ? popout.theme.accent : (hover.containsMouse ? popout.theme.text : popout.theme.subtext)

        MouseArea {
            id: hover

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: PowerProfiles.profile = button.profile
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
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 8

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        theme: popout.theme
                        name: "brightness"
                        color: popout.theme.text
                    }

                    LevelSlider {
                        width: parent.width - 16 - 8 - percentText.width - 8
                        anchors.verticalCenter: parent.verticalCenter
                        value: popout.percent / 100
                        onMoved: value => popout.setPercent(Math.round(value * 100))
                    }

                    Text {
                        id: percentText

                        width: 34
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: popout.percent + "%"
                        color: popout.theme.text
                        font.family: popout.theme.fontFamily
                        font.pixelSize: popout.theme.fontSizeSmall
                    }
                }

                Loader {
                    active: popout.profilesAvailable
                    width: popout.width - 24
                    sourceComponent: Column {
                        width: popout.width - 24
                        spacing: 6

                        Text {
                            text: "Power profile"
                            color: popout.theme.subtext
                            font.family: popout.theme.fontFamily
                            font.pixelSize: popout.theme.fontSizeTiny
                        }

                        Row {
                            spacing: 16

                            ProfileButton {
                                profile: PowerProfile.PowerSaver
                                name: "leaf"
                            }

                            ProfileButton {
                                profile: PowerProfile.Balanced
                                name: "balance"
                            }

                            ProfileButton {
                                profile: PowerProfile.Performance
                                name: "flash"
                            }
                        }
                    }
                }
            }
        }
    }

    // Hover tracking only; does not consume presses, so the slider still works.
}
