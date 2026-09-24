// Hover preview of a workspace: a floating card under the workspace indicator
// showing every window on that workspace as a live capture at its Hyprland
// geometry (so overlapping/hidden windows are visible). Clicking a window
// focuses it, switching workspace if needed.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: preview

    required property Theme theme

    // The workspace to preview (null hides the card) and the x of the bar item
    // it should drop under (the item's centre, in screen coordinates).
    property var workspace: null
    property real anchorX: 0

    // The owner closes us (it holds the open/closed state); assigning
    // `workspace` here would break the binding that feeds it.
    signal windowActivated()

    readonly property int padding: 8
    readonly property int canvasWidth: 480
    readonly property var monitor: workspace ? workspace.monitor : null
    // Hyprland reports monitor width/height in physical pixels but window
    // geometry in logical pixels, so divide by the monitor scale before
    // deriving the canvas scale (otherwise a scaled display halves everything).
    readonly property real monitorScale: monitor && monitor.scale > 0 ? monitor.scale : 1
    readonly property real logicalWidth: monitor ? monitor.width / monitorScale : 0
    readonly property real logicalHeight: monitor ? monitor.height / monitorScale : 0
    readonly property real scale: logicalWidth > 0 ? canvasWidth / logicalWidth : 1
    readonly property int canvasHeight: logicalWidth > 0 ? Math.round(logicalHeight * scale) : 270
    readonly property var toplevels: workspace ? workspace.toplevels.values : []
    // Hover is tracked from the card background and every thumbnail, since one
    // overlay would swallow the thumbnails' own hover.
    property int hoveredThumbs: 0
    readonly property bool hovered: bgArea.containsMouse || hoveredThumbs > 0

    function thumbHover(active): void {
        hoveredThumbs += active ? 1 : -1;
    }

    visible: workspace !== null
    implicitWidth: canvasWidth + padding * 2
    implicitHeight: canvasHeight + padding * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-preview"

    anchors {
        top: true
        left: true
    }
    margins.top: 38
    margins.left: {
        const maxLeft = (screen ? screen.width : 1280) - implicitWidth - 8;
        return Math.max(8, Math.min(Math.round(anchorX - implicitWidth / 2), maxLeft));
    }

    // Window geometry is only (re)fetched on request, so do it when we open.
    onWorkspaceChanged: {
        hoveredThumbs = 0;
        if (workspace)
            Hyprland.refreshToplevels();
    }

    Rectangle {
        anchors.fill: parent
        radius: preview.theme.radius
        color: preview.theme.surface
        border.width: 1
        border.color: preview.theme.border

        MouseArea {
            id: bgArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Item {
            id: canvas

            anchors.centerIn: parent
            width: preview.canvasWidth
            height: preview.canvasHeight
            clip: true

            Text {
                anchors.centerIn: parent
                visible: preview.toplevels.length === 0
                text: "Empty workspace"
                color: preview.theme.overlay
                font.family: preview.theme.fontFamily
                font.pixelSize: preview.theme.fontSizeSmall
            }

            Repeater {
                model: preview.toplevels

                Item {
                    required property var modelData

                    readonly property var info: modelData.lastIpcObject || ({})

                    visible: width > 0 && height > 0
                    x: preview.monitor && info.at ? (info.at[0] - preview.monitor.x) * preview.scale : 0
                    y: preview.monitor && info.at ? (info.at[1] - preview.monitor.y) * preview.scale : 0
                    width: info.size ? Math.max(8, info.size[0] * preview.scale) : 0
                    height: info.size ? Math.max(8, info.size[1] * preview.scale) : 0

                    // ClippingRectangle rounds the capture and keeps the border
                    // inside the thumbnail (so it is not clipped at the bottom).
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 3
                        color: "transparent"
                        contentUnderBorder: true
                        border.width: itemMouse.containsMouse ? 3 : modelData.activated ? 2 : 1
                        border.color: itemMouse.containsMouse || modelData.activated ? preview.theme.accent : preview.theme.border

                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: preview.visible ? modelData.wayland : null
                            live: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: preview.theme.accent
                            opacity: itemMouse.containsMouse ? 0.15 : 0
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            height: 18
                            visible: itemMouse.containsMouse
                            color: preview.theme.base
                            opacity: 0.8

                            Text {
                                anchors {
                                    fill: parent
                                    leftMargin: 4
                                    rightMargin: 4
                                }
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: modelData.title
                                color: preview.theme.text
                                font.family: preview.theme.fontFamily
                                font.pixelSize: preview.theme.fontSizeTiny
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: preview.thumbHover(containsMouse)
                        onClicked: {
                            if (modelData.wayland)
                                modelData.wayland.activate();
                            preview.windowActivated();
                        }
                    }
                }
            }
        }
    }
}
