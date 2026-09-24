// Themed popup for a tray item's D-Bus menu, with cascading submenus.
//
// QML forbids a component instantiating itself (directly or through a cycle),
// so submenus are not nested components: the open submenu chain is held as a
// `path` of entries and every level is drawn as a column in this one window.
// That also means the whole cascade shares a single hover surface, so there is
// no parent/submenu hover handoff to get wrong.
//
// Submenus grow leftwards (root column under the icon, deepest column leftmost)
// because the tray sits at the screen's right edge.
//
// The owner drives open/pinned from a PopoutState, exactly like the volume
// popout: hover opens after a delay, a click pins it, and a pinned menu closes
// when focus is lost.
import Quickshell
import Quickshell.Hyprland
import QtQuick

PopupWindow {
    id: trayMenu

    required property Theme theme

    property var handle: null
    property bool open: false
    property bool pinned: false
    // The root menu of a stack owns the focus grab; kept for the submenu-era
    // API, all menus here are roots.
    property bool isRoot: true

    signal focusLost()
    signal closeRequested()

    // path[i] is the entry whose children form column i+1. Depth 0 is the root
    // menu's own entries, taken from `handle`.
    property var path: []

    readonly property bool hovered: menuHover.hovered
    readonly property int columns: path.length + 1

    function isExpanded(depth, entry): bool {
        return depth < path.length && path[depth] === entry;
    }

    function openSubmenu(depth, entry): void {
        path = path.slice(0, depth).concat([entry]);
    }

    function collapse(depth): void {
        if (depth < path.length)
            path = path.slice(0, depth);
    }

    // Hovering a row either opens its submenu or, for a leaf, collapses any
    // columns deeper than it. Moving right into a submenu column re-hovers a row
    // at the new depth, so nothing else is needed to keep the chain open.
    function hoverEntry(depth, entry): void {
        if (entry.hasChildren)
            openSubmenu(depth, entry);
        else
            collapse(depth);
    }

    function trigger(entry): void {
        if (entry && entry.enabled)
            entry.triggered();
    }

    function closeAll(): void {
        path = [];
        closeRequested();
    }

    visible: trayMenu.open && trayMenu.handle !== null
    color: "transparent"
    implicitWidth: menuRow.implicitWidth + 16
    implicitHeight: menuRow.implicitHeight + 16
    grabFocus: false

    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.adjustment: PopupAdjustment.SlideY

    HyprlandFocusGrab {
        active: trayMenu.isRoot && trayMenu.open && trayMenu.pinned
        windows: [trayMenu]
        onCleared: trayMenu.focusLost()
    }

    Rectangle {
        anchors.fill: parent
        radius: trayMenu.theme.radius
        color: trayMenu.theme.surface
        border.width: 1
        border.color: trayMenu.theme.border

        Row {
            id: menuRow

            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: trayMenu.columns

                MenuColumn {
                    required property int index

                    menu: trayMenu
                    handle: trayMenu.handle
                    // Leftmost column is the deepest so the root sits under the icon.
                    depth: trayMenu.columns - 1 - index
                    entry: depth === 0 ? null : trayMenu.path[depth - 1]
                }
            }
        }
    }

    // Hover tracking only; does not consume presses, so the rows still work.
    Item {
        anchors.fill: parent

        HoverHandler {
            id: menuHover
        }
    }
}
