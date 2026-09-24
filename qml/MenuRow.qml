// One row of a MenuColumn: a separator, a leaf entry, or a submenu parent.
//
// The row owns no submenu of its own; hovering a parent asks the TrayMenu to
// expand that entry, and the menu draws the children as a new column.
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: row

    required property var menu
    property int depth: 0
    property var entry: null

    readonly property bool separator: entry !== null && entry.isSeparator
    readonly property bool hasChildren: entry !== null && entry.hasChildren
    readonly property bool entryEnabled: entry !== null && entry.enabled
    readonly property bool expanded: entry !== null && menu.isExpanded(depth, entry)

    implicitHeight: separator ? 9 : 30
    implicitWidth: rowLayout.implicitWidth + 20
    width: parent ? parent.width : implicitWidth

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: row.separator
        width: parent.width
        height: 1
        color: row.menu.theme.surfaceAlt
    }

    Rectangle {
        anchors.fill: parent
        visible: !row.separator
        radius: row.menu.theme.itemRadius
        color: (hover.containsMouse || row.expanded) && row.entryEnabled
            ? row.menu.theme.surfaceAlt
            : "transparent"
    }

    RowLayout {
        id: rowLayout

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 10
            rightMargin: 10
        }
        visible: !row.separator
        spacing: 8

        Glyph {
            visible: row.entry !== null && row.entry.buttonType !== QsMenuButtonType.None
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            theme: row.menu.theme
            size: row.menu.theme.fontSizeSmall
            color: row.entry && row.entry.checkState === Qt.Checked ? row.menu.theme.accent : row.menu.theme.overlay
            name: {
                if (!row.entry)
                    return "";
                if (row.entry.buttonType === QsMenuButtonType.RadioButton)
                    return row.entry.checkState === Qt.Checked ? "radio" : "radio-off";
                return row.entry.checkState === Qt.Checked ? "check" : "";
            }
        }

        IconImage {
            visible: row.entry !== null && row.entry.icon !== ""
            Layout.preferredWidth: visible ? 16 : 0
            Layout.preferredHeight: 16
            implicitSize: 16
            source: row.entry ? row.entry.icon : ""
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            color: row.entryEnabled ? row.menu.theme.text : row.menu.theme.overlay
            font.family: row.menu.theme.fontFamily
            font.pixelSize: row.menu.theme.fontSizeSmall
            text: row.entry ? row.entry.text : ""
        }

        Glyph {
            visible: row.hasChildren
            Layout.preferredWidth: 10
            Layout.preferredHeight: 14
            theme: row.menu.theme
            size: row.menu.theme.fontSizeSmall
            name: "chevron-left"
            color: row.menu.theme.overlay
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        enabled: !row.separator && row.entryEnabled
        acceptedButtons: Qt.LeftButton

        onContainsMouseChanged: {
            if (containsMouse && !row.separator && row.entryEnabled)
                row.menu.hoverEntry(row.depth, row.entry);
        }

        onClicked: {
            if (row.hasChildren) {
                row.menu.openSubmenu(row.depth, row.entry);
            } else {
                row.menu.trigger(row.entry);
                row.menu.closeAll();
            }
        }
    }
}
