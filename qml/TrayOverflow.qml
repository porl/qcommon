// Grid of tray icons that did not fit on the bar, opened from the expander.
//
// Opened by clicking the expander and pinned while open; a focus grab (as with
// the tray menus) is what lets the icons inside receive pointer events. It
// closes on a click outside, or after an icon is activated.
//
// Do NOT add a full-size HoverHandler overlay (as an earlier version had): it
// swallows hover from the icons beneath, so their tooltips never appear.
//
// The grid is square-ish rather than a fixed four columns, so a couple of
// hidden icons do not leave a wide empty row, and it tracks which of its icons
// has a menu open so only one shows at a time (the bar has the same rule, but
// this popup is not the bar's expander popout).
import Quickshell
import Quickshell.Hyprland
import QtQuick

PopupWindow {
    id: overflow

    required property Theme theme
    property var items: []
    property bool open: false

    signal focusLost()
    signal activated()

    // The menu PopoutState currently open among the grid's icons.
    property var activePopout: null
    // Prefer a near-square grid; at least two columns when there is more than
    // one icon, capped at four so the popup does not grow sideways.
    readonly property int columns: items.length <= 1 ? 1 : Math.min(4, Math.ceil(Math.sqrt(items.length)))

    function claimMenu(state): void {
        if (activePopout && activePopout !== state)
            activePopout.close();
        activePopout = state;
    }

    // Closing the grid closes any menu its icons had open.
    onOpenChanged: {
        if (!open && activePopout) {
            activePopout.close();
            activePopout = null;
        }
    }

    visible: overflow.open
    color: "transparent"
    implicitWidth: grid.width + 20
    implicitHeight: grid.height + 20

    // Anchored to the whole tray (the owner sets anchor.item) and dropped
    // below it, centred; the adjustment keeps it on-screen at the bar's right.
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.All

    // Pinned while open; the grab is what gives the popup pointer input, as
    // with the tray menus. A click outside clears it and closes the panel.
    HyprlandFocusGrab {
        active: overflow.open
        windows: [overflow]
        onCleared: overflow.focusLost()
    }

    Rectangle {
        anchors.fill: parent
        radius: overflow.theme.radius
        color: overflow.theme.surface
        border.width: 1
        border.color: overflow.theme.border

        Grid {
            id: grid

            anchors.centerIn: parent
            columns: overflow.columns
            spacing: 4

            Repeater {
                model: overflow.items

                TrayItem {
                    required property var modelData

                    theme: overflow.theme
                    item: modelData
                    claim: overflow.claimMenu
                    onActivated: overflow.activated()
                }
            }
        }
    }
}
