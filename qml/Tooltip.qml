// Hover tooltip for a bar or tray item: a small themed card below the item
// with a title and, when the item provides one, a description line.
//
// It is non-interactive: it never grabs focus or presses, and the owner drives
// `open`. Anchored as a popup so it follows the item wherever it is (on the bar
// or inside the overflow grid).
import Quickshell
import QtQuick

PopupWindow {
    id: tooltip

    required property Theme theme
    // The item to point at.
    property var item: null
    property string title: ""
    property string description: ""
    property bool open: false

    readonly property bool hasText: title !== "" || description !== ""

    visible: open && hasText && item !== null
    color: "transparent"
    implicitWidth: card.width
    implicitHeight: card.height
    grabFocus: false

    anchor.item: item
    // Anchor to the item's bottom edge and grow down, so the card sits below
    // the icon. Anchoring to the top edge would make the popup cover the icon
    // (stealing hover and clicks, and flickering).
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.SlideX

    Rectangle {
        id: card

        width: column.width + 16
        height: column.height + 12
        radius: tooltip.theme.itemRadius
        color: tooltip.theme.surface
        border.width: 1
        border.color: tooltip.theme.border

        Column {
            id: column

            anchors.centerIn: parent
            width: Math.min(280, Math.max(titleText.implicitWidth, descriptionText.implicitWidth))
            spacing: 2

            Text {
                id: titleText

                width: column.width
                elide: Text.ElideRight
                text: tooltip.title
                color: tooltip.theme.text
                font.family: tooltip.theme.fontFamily
                font.pixelSize: tooltip.theme.fontSizeSmall
            }

            Text {
                id: descriptionText

                visible: text !== ""
                width: column.width
                elide: Text.ElideRight
                text: tooltip.description
                color: tooltip.theme.overlay
                font.family: tooltip.theme.fontFamily
                font.pixelSize: tooltip.theme.fontSizeTiny
            }
        }
    }
}
