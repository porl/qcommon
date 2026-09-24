// One column of a TrayMenu: the root menu's entries (entry null, using handle)
// or the children of `entry`, one column per level of the open submenu chain.
import Quickshell
import QtQuick

Item {
    id: column

    // The TrayMenu that owns the open/close state.
    required property var menu
    // Root handle, used when this is the root column.
    required property var handle
    // The QsMenuEntry whose children this column shows, or null for the root.
    required property var entry
    required property int depth

    readonly property var entries: opener.children ? opener.children.values : []

    QsMenuOpener {
        id: opener

        menu: column.entry !== null ? column.entry : column.handle
    }

    implicitWidth: 220
    implicitHeight: entriesColumn.implicitHeight
    width: implicitWidth

    Column {
        id: entriesColumn

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: 2

        Repeater {
            model: column.entries

            MenuRow {
                required property var modelData

                menu: column.menu
                depth: column.depth
                entry: modelData
            }
        }
    }
}
