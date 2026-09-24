// Workspace indicator for the bar: one entry per workspace, grouped by monitor
// in monitor-position order, driven by Quickshell's Hyprland integration (no
// `hyprctl`/shell polling). Clicking a workspace activates it; hovering one
// opens a live window preview of that workspace below.
import Quickshell
import Quickshell.Hyprland
import QtQuick

Row {
    id: workspaces

    required property Theme theme
    // The screen this bar is on. When set (one bar per monitor), only that
    // monitor's workspaces are shown; otherwise all monitors are.
    property var screen: null

    // Shared with WorkspacePreview: the workspace under the pointer and the x
    // (screen coordinates) of the bar item it belongs to.
    property var hoveredWorkspace: null
    property real previewAnchorX: 0
    property bool previewOpen: false
    property bool itemHovered: false
    property bool previewHovered: false

    spacing: 2

    readonly property var sortedMonitors: {
        var monitors = Hyprland.monitors.values
            .slice()
            .sort((a, b) => a.y !== b.y ? a.y - b.y : a.x !== b.x ? a.x - b.x : a.id - b.id);
        if (screen) {
            var matching = monitors.filter(m => m.name === screen.name);
            if (matching.length > 0)
                return matching;
        }
        return monitors;
    }

    function workspacesFor(monitor): var {
        return Hyprland.workspaces.values
            .filter(ws => ws.monitor === monitor && !ws.name.startsWith("special:"))
            .sort((a, b) => a.id - b.id)
    }

    function showPreview(workspace, anchor): void {
        // No card for an empty workspace.
        if (!workspace || workspace.toplevels.values.length === 0) {
            previewOpen = false;
            return;
        }
        hoveredWorkspace = workspace;
        previewAnchorX = anchor;
        previewOpen = true;
        closeTimer.stop();
    }

    // Keep the card open when the pointer moves from the bar item into it.
    Timer {
        id: closeTimer

        interval: 150
        onTriggered: if (!workspaces.itemHovered && !workspaces.previewHovered) workspaces.previewOpen = false
    }

    onPreviewHoveredChanged: {
        if (previewHovered) {
            closeTimer.stop();
            previewOpen = true;
        } else {
            closeTimer.restart();
        }
    }

    Repeater {
        model: workspaces.sortedMonitors

        Row {
            required property var modelData
            required property int index

            spacing: 2

            // Hit area for the screen's top-left corner: activates/previews the
            // first workspace, so the 8px leading margin is not a dead zone.
            MouseArea {
                width: index === 0 ? 8 : 0
                height: workspaces.height
                hoverEnabled: true

                readonly property var firstWorkspace: workspaces.sortedMonitors.length > 0 ? workspaces.workspacesFor(workspaces.sortedMonitors[0])[0] : null

                onClicked: if (firstWorkspace)
                    firstWorkspace.activate()
                onContainsMouseChanged: {
                    if (containsMouse) {
                        if (firstWorkspace) {
                            workspaces.itemHovered = true;
                            workspaces.showPreview(firstWorkspace, mapToItem(null, width / 2, 0).x);
                        }
                    } else {
                        workspaces.itemHovered = false;
                        closeTimer.restart();
                    }
                }
            }

            Repeater {
                model: workspaces.workspacesFor(modelData)

                Item {
                    required property var modelData

                    width: 20
                    height: workspaces.height

                    readonly property bool empty: modelData.toplevels.values.length === 0

                    Text {
                        anchors.centerIn: parent
                        // Label workspace 10 as "0" (there is no tenth digit).
                        text: modelData.id === 10 ? "0" : modelData.name
                        font.family: workspaces.theme.fontFamily
                        font.pixelSize: workspaces.theme.fontSize
                        color: {
                            if (hover.containsMouse || modelData.focused)
                                return workspaces.theme.accent;
                            if (modelData.urgent)
                                return workspaces.theme.danger;
                            if (modelData.active)
                                return workspaces.theme.text;
                            if (empty)
                                return workspaces.theme.overlay;
                            return workspaces.theme.subtext;
                        }
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            workspaces.previewOpen = false;
                            modelData.activate();
                        }
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                workspaces.itemHovered = true;
                                workspaces.showPreview(modelData, hover.mapToItem(null, width / 2, 0).x);
                            } else {
                                workspaces.itemHovered = false;
                                closeTimer.restart();
                            }
                        }
                    }
                }
            }

            Text {
                height: workspaces.height
                verticalAlignment: Text.AlignVCenter
                visible: index < workspaces.sortedMonitors.length - 1
                text: "|"
                color: workspaces.theme.overlay
                font.family: workspaces.theme.fontFamily
                font.pixelSize: workspaces.theme.fontSizeSmall
            }
        }
    }

    WorkspacePreview {
        id: preview

        theme: workspaces.theme
        workspace: workspaces.previewOpen ? workspaces.hoveredWorkspace : null
        anchorX: workspaces.previewAnchorX
        onHoveredChanged: workspaces.previewHovered = hovered
        onWindowActivated: workspaces.previewOpen = false
    }
}
