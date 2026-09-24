// One StatusNotifierItem icon. Left click runs the primary action (or opens the
// menu for menu-only items), middle click the secondary action, right click the
// menu; scroll is forwarded to the item.
//
// Hover shows the item's title (and description) as a tooltip; the menu opens
// on right click (or left click for menu-only items) and, once open, pins until
// focus is lost. Nothing opens a menu on hover — the shared PopoutState only
// supplies the pin / close-on-focus-loss policy here.
import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property Theme theme
    property var item: null
    property int iconSize: theme.trayIconSize
    // Registration callback so the tray can close any other open menu.
    property var claim: null

    readonly property bool hasMenu: item !== null && item.hasMenu
    readonly property int cellWidth: iconSize + 10
    readonly property int cellHeight: iconSize + 10
    readonly property bool menuOpen: popout.open

    readonly property string tooltipTitle: item ? (item.tooltipTitle || item.title) : ""
    readonly property string tooltipDescription: item ? item.tooltipDescription : ""
    // Stands in for a missing or undecodable icon: the first letter of the
    // item's title (or id), so it is still identifiable and clickable.
    readonly property string fallbackLetter: {
        var source = item ? (item.title || item.id || "") : "";
        var match = source.trim().match(/[A-Za-z0-9]/);
        return match ? match[0].toUpperCase() : "?";
    }

    signal menuVisibilityChanged(bool open)
    signal activated()

    implicitWidth: cellWidth
    implicitHeight: cellHeight

    property PopoutState popout: PopoutState {}

    onMenuOpenChanged: {
        if (menuOpen) {
            tooltipShow.stop();
            tip.open = false;
            if (claim)
                claim(popout);
        }
        root.menuVisibilityChanged(menuOpen);
    }

    function closeMenu(): void {
        popout.close();
    }

    IconImage {
        id: icon

        // A themed icon name resolves through Quickshell's image provider, so a
        // load failure (Image.Error) is the reliable "no icon" signal, not an
        // empty source.
        anchors.centerIn: parent
        visible: root.item !== null && root.item.icon !== "" && status !== Image.Error
        implicitSize: root.iconSize
        width: root.iconSize
        height: root.iconSize
        source: root.item ? root.item.icon : ""
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        radius: 4
        visible: !icon.visible
        color: root.theme.surfaceAlt

        Text {
            anchors.centerIn: parent
            text: root.fallbackLetter
            color: root.theme.text
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSizeSmall
        }
    }

    Tooltip {
        id: tip

        theme: root.theme
        item: root
        title: root.tooltipTitle
        description: root.tooltipDescription
    }

    // Delay the tooltip so brushing across the tray does not flash cards.
    Timer {
        id: tooltipShow

        interval: 600
        onTriggered: if (hover.containsMouse && !root.menuOpen) tip.open = true
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onContainsMouseChanged: {
            if (containsMouse)
                tooltipShow.restart();
            else {
                tooltipShow.stop();
                tip.open = false;
            }
        }

        onClicked: mouse => {
            if (!root.item)
                return;
            tip.open = false;
            if (mouse.button === Qt.MiddleButton) {
                hoveredClose();
                root.item.secondaryActivate();
                root.activated();
            } else if (mouse.button === Qt.RightButton) {
                // Right click is the context menu; with no menu there is
                // nothing to show.
                if (root.hasMenu)
                    root.popout.activate();
            } else if (root.item.onlyMenu && root.hasMenu) {
                root.popout.activate();
            } else {
                hoveredClose();
                root.item.activate();
                root.activated();
            }
        }

        // Scroll is forwarded to the item; it deliberately does not open the
        // menu (opening a menu from a wheel event is surprising).
        onWheel: event => {
            if (!root.item)
                return;
            root.item.scroll(event.angleDelta.y, event.angleDelta.x !== 0);
        }

        // A left/middle activation is terminal: drop a menu left open from an
        // earlier click (a pinned menu is dismissed by clicking outside).
        function hoveredClose(): void {
            if (root.menuOpen && !root.popout.pinned)
                root.popout.close();
        }
    }

    TrayMenu {
        theme: root.theme
        handle: root.item ? root.item.menu : null
        open: root.popout.open && root.hasMenu
        pinned: root.popout.pinned
        isRoot: true
        anchor.item: root

        onHoveredChanged: hovered ? root.popout.contentEntered() : root.popout.contentExited()
        onFocusLost: root.popout.focusLost()
        onCloseRequested: root.popout.close()
    }
}
