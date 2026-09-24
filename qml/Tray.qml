// System tray block for the bar.
//
// Shows at most `maxVisible` StatusNotifierItems; the rest collapse behind an
// expander whose popup is a grid of the hidden icons. The expander follows the
// icons (on the right). Every icon — on the bar or in the grid — uses TrayItem,
// so menu/mouse behaviour is identical in both places.
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Item {
    id: tray

    required property Theme theme
    // Room the bar can spare, derived from the gap between the clock and the
    // fixed right-hand blocks (see Bar.qml).
    property real maxWidth: 0

    readonly property int iconSize: theme.trayIconSize
    readonly property int cellWidth: iconSize + 10
    readonly property int cellHeight: iconSize + 10
    readonly property int spacing: 4
    readonly property int stride: cellWidth + spacing

    // Never fill the bar with tray icons; past this many the rest collapse.
    // Overridable for testing overflow: QSHELL_TRAY_MAX_VISIBLE=3.
    readonly property int maxVisible: {
        var v = parseInt(Quickshell.env("QSHELL_TRAY_MAX_VISIBLE"));
        return isNaN(v) || v < 1 ? 6 : v;
    }

    readonly property var items: SystemTray.items.values
    readonly property int count: items.length

    // Icons we are willing to show: our own cap, further limited by the space
    // the bar can actually spare before the centred clock.
    readonly property int spaceCells: Math.max(0, Math.floor((maxWidth + spacing) / stride))
    readonly property int limit: Math.min(spaceCells, maxVisible)
    readonly property bool overflow: count > limit
    readonly property int visibleCount: overflow ? Math.max(0, limit - 1) : count
    readonly property var visibleItems: items.slice(0, visibleCount)
    readonly property var hiddenItems: overflow ? items.slice(visibleCount, count) : []
    readonly property int shownCells: visibleCount + (overflow ? 1 : 0)

    // Only one menu may be open at a time; each TrayItem claims this slot when
    // it opens.
    property var activePopout: null

    function claimPopout(state): void {
        if (activePopout && activePopout !== state)
            activePopout.close();
        activePopout = state;
    }

    visible: count > 0
    implicitWidth: shownCells > 0 ? shownCells * stride - spacing : 0

    Row {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        height: tray.height
        spacing: tray.spacing

        Repeater {
            model: tray.visibleItems

            TrayItem {
                required property var modelData

                theme: tray.theme
                item: modelData
                iconSize: tray.iconSize
                claim: tray.claimPopout
            }
        }

        // Rightmost, after the icons: the affordance for the hidden ones. It
        // changes colour on hover, like the other bar blocks — no background.
        Item {
            id: expander

            visible: tray.overflow
            width: visible ? tray.cellWidth : 0
            height: visible ? tray.cellHeight : 0

            property PopoutState popout: PopoutState {
                openDelay: 250
            }

            Connections {
                target: expander.popout

                function onOpenChanged() {
                    if (expander.popout.open)
                        tray.claimPopout(expander.popout);
                }
            }

            Glyph {
                anchors.centerIn: parent
                theme: tray.theme
                name: "chevron-double-right"
                // Slightly smaller than the icons.
                size: tray.theme.trayIconSize - 2
                color: hover.containsMouse || expander.popout.open ? tray.theme.accent : tray.theme.text
            }

            MouseArea {
                id: hover

                anchors.fill: parent
                hoverEnabled: true

                // Click-only: unlike the bar icons, the panel is pinned and
                // takes a focus grab (see TrayOverflow), which is what lets the
                // icons inside it receive pointer events. Hovering the chevron
                // only changes its colour.
                onClicked: expander.popout.open ? expander.popout.close() : expander.popout.activate()
            }

            TrayOverflow {
                theme: tray.theme
                items: tray.hiddenItems
                open: expander.popout.open

                anchor.item: tray
                onFocusLost: expander.popout.close()
                onActivated: expander.popout.close()
            }
        }
    }
}
