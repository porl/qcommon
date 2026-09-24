// Drop-down calendar, opened from the clock. A month grid with prev/next
// navigation; clicking a day selects it and shows the full date and how far
// away it is. Clicking the selected day again (or double-clicking) opens the
// configured calendar app for that date — `QSHELL_CALENDAR` is a shell command
// template and `{date}` is replaced with the ISO date (apps that ignore the
// argument simply open as usual).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: calendar

    required property Theme theme
    // The clock's centre in screen coordinates; the card centres under it.
    property real anchorX: 0

    // Owner-driven open/pin state (PopoutState).
    property bool open: false
    property bool pinned: false
    signal focusLost()
    signal dismissRequested()

    readonly property bool hovered: popupHover.hovered

    readonly property int cardWidth: 280
    readonly property int weekStart: (Quickshell.env("QSHELL_WEEK_START") || "mon").toLowerCase().startsWith("s") ? 0 : 1

    // Only as many week rows as the month actually needs (4-6).
    readonly property int daysInMonth: new Date(shownYear, shownMonth + 1, 0).getDate()
    readonly property int firstOffset: {
        var first = new Date(shownYear, shownMonth, 1);
        return (first.getDay() - weekStart + 7) % 7;
    }
    readonly property int rows: Math.ceil((firstOffset + daysInMonth) / 7)

    property int shownYear: today.getFullYear()
    property int shownMonth: today.getMonth()
    property date selected: today
    readonly property date today: {
        var d = new Date();
        d.setHours(0, 0, 0, 0);
        return d;
    }

    function dayAt(index): date {
        var first = new Date(shownYear, shownMonth, 1);
        var offset = (first.getDay() - weekStart + 7) % 7;
        return new Date(shownYear, shownMonth, 1 - offset + index);
    }

    function sameDay(a, b): bool {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function shiftMonth(delta): void {
        var m = shownMonth + delta;
        shownYear += Math.floor(m / 12);
        shownMonth = ((m % 12) + 12) % 12;
    }

    function goToday(): void {
        shownYear = today.getFullYear();
        shownMonth = today.getMonth();
        selected = today;
    }

    function openApp(d): void {
        var template = Quickshell.env("QSHELL_CALENDAR");
        if (!template)
            return;
        var iso = Qt.formatDate(d, "yyyy-MM-dd");
        Quickshell.execDetached(["sh", "-c", template.replace(/\{date\}/g, iso)]);
        calendar.dismissRequested();
    }

    // A nav chevron: one of our own glyphs, coloured on hover. The title is a
    // separate item so the four buttons stay symmetric around it.
    component NavButton: Item {
        id: nav

        property string glyph: ""
        property int glyphSize: calendar.theme.fontSize
        signal triggered()

        width: 20
        height: 24

        Glyph {
            anchors.centerIn: parent
            theme: calendar.theme
            name: nav.glyph
            size: nav.glyphSize
            color: navHover.containsMouse ? calendar.theme.accent : calendar.theme.subtext
        }

        MouseArea {
            id: navHover

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: nav.triggered()
        }
    }

    visible: open
    implicitWidth: cardWidth
    implicitHeight: layout.implicitHeight + 20
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-calendar"

    anchors {
        top: true
        left: true
    }
    margins.top: 38
    margins.left: {
        var screenWidth = screen ? screen.width : 1920;
        return Math.max(8, Math.min(Math.round(calendar.anchorX - cardWidth / 2), screenWidth - cardWidth - 8));
    }

    HyprlandFocusGrab {
        active: calendar.open && calendar.pinned
        windows: [calendar]
        onCleared: calendar.focusLost()
    }

    Rectangle {
        anchors.fill: parent
        radius: calendar.theme.radius
        color: calendar.theme.surface
        border.width: 1
        border.color: calendar.theme.border

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: layout

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 6

            Row {
                width: parent.width
                height: 24
                spacing: 4

                NavButton {
                    width: 24
                    glyph: "chevron-double-left"
                    glyphSize: calendar.theme.fontSizeSmall
                    onTriggered: calendar.shownYear -= 1
                }

                NavButton {
                    glyph: "chevron-left"
                    onTriggered: calendar.shiftMonth(-1)
                }

                Text {
                    width: parent.width - 24 - 20 - 20 - 24 - 16
                    height: 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.formatDate(new Date(calendar.shownYear, calendar.shownMonth, 1), "MMMM yyyy")
                    color: title.containsMouse ? calendar.theme.accent : calendar.theme.text
                    font.family: calendar.theme.fontFamily
                    font.pixelSize: calendar.theme.fontSizeSmall
                    MouseArea {
                        id: title
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: calendar.goToday()
                    }
                }

                NavButton {
                    glyph: "chevron-right"
                    onTriggered: calendar.shiftMonth(1)
                }

                NavButton {
                    width: 24
                    glyph: "chevron-double-right"
                    glyphSize: calendar.theme.fontSizeSmall
                    onTriggered: calendar.shownYear += 1
                }
            }

            Row {
                width: parent.width
                spacing: 0

                Repeater {
                    model: 7

                    Text {
                        required property int index

                        width: (layout.width) / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(calendar.dayAt(index), "ddd")
                        color: calendar.theme.overlay
                        font.family: calendar.theme.fontFamily
                        font.pixelSize: calendar.theme.fontSizeTiny
                    }
                }
            }

            GridView {
                id: grid

                width: parent.width
                height: cellHeight * calendar.rows
                cellWidth: width / 7
                cellHeight: 30
                interactive: false
                model: calendar.rows * 7

                delegate: Rectangle {
                    required property int index

                    readonly property date day: calendar.dayAt(index)
                    readonly property bool inMonth: day.getMonth() === calendar.shownMonth && day.getFullYear() === calendar.shownYear
                    readonly property bool isToday: calendar.sameDay(day, calendar.today)
                    readonly property bool isSelected: calendar.sameDay(day, calendar.selected)

                    width: grid.cellWidth
                    height: grid.cellHeight
                    radius: calendar.theme.itemRadius
                    color: isSelected ? calendar.theme.accent : (dayMouse.containsMouse ? calendar.theme.surfaceAlt : "transparent")
                    border.width: isToday && !isSelected ? 1 : 0
                    border.color: calendar.theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: parent.day.getDate()
                        color: parent.isSelected ? calendar.theme.base : (parent.inMonth ? calendar.theme.text : calendar.theme.overlay)
                        font.family: calendar.theme.fontFamily
                        font.pixelSize: calendar.theme.fontSizeSmall
                        font.bold: parent.isToday
                    }

                    MouseArea {
                        id: dayMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (calendar.sameDay(parent.day, calendar.selected))
                                calendar.openApp(parent.day);
                            else
                                calendar.selected = parent.day;
                        }
                        onDoubleClicked: calendar.openApp(parent.day)
                    }
                }
            }

        }
    }

    // Hover tracking only; does not consume presses.
    Item {
        anchors.fill: parent

        HoverHandler {
            id: popupHover
        }
    }
}
