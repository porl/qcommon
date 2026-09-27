// A month's weekday header and day cells. The days are built as explicit rows
// of seven rather than a wrapping view, so a fractional cell width can never
// collapse a column (a GridView's column count comes from width / cellWidth,
// which floors to six for e.g. 260 / (260 / 7)). Pure QtQuick apart from Theme,
// so qmltestrunner pins the layout; clicking emits the day and the consumer
// decides what a click means.
import QtQuick

Item {
    id: grid

    required property Theme theme
    property int shownYear: 1970
    property int shownMonth: 0
    // 0 Sunday, 1 Monday.
    property int weekStart: 1
    property date selected
    // ISO date ("yyyy-MM-dd") -> true for days that get a dot. The consumer
    // builds it (the agenda command's marker output); null means no dots.
    property var markedDays: null

    readonly property date today: {
        var d = new Date();
        d.setHours(0, 0, 0, 0);
        return d;
    }

    readonly property int daysInMonth: new Date(shownYear, shownMonth + 1, 0).getDate()
    readonly property int firstOffset: {
        var first = new Date(shownYear, shownMonth, 1);
        return (first.getDay() - weekStart + 7) % 7;
    }
    readonly property int rows: Math.ceil((firstOffset + daysInMonth) / 7)

    readonly property int cellHeight: 30
    readonly property real cellWidth: width / 7

    signal dayClicked(date day)
    signal dayDoubleClicked(date day)

    function dayAt(index): date {
        var first = new Date(shownYear, shownMonth, 1);
        return new Date(shownYear, shownMonth, 1 - firstOffset + index);
    }

    function sameDay(a, b): bool {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    implicitWidth: cellWidth * 7
    implicitHeight: header.height + days.height
    // A container: give it real bounds so hit-testing and the card's Column
    // both see the content (implicitHeight alone is only a hint).
    height: implicitHeight

    Row {
        id: header

        width: grid.width

        Repeater {
            model: 7

            Text {
                required property int index

                width: grid.cellWidth
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(grid.dayAt(index), "ddd")
                color: grid.theme.overlay
                font.family: grid.theme.fontFamily
                font.pixelSize: grid.theme.fontSizeTiny
            }
        }
    }

    Grid {
        id: days

        anchors.top: header.bottom
        width: grid.width
        columns: 7

        Repeater {
            model: grid.rows * 7

            Rectangle {
                id: cell

                required property int index

                readonly property date day: grid.dayAt(index)
                readonly property bool inMonth: day.getMonth() === grid.shownMonth && day.getFullYear() === grid.shownYear
                readonly property bool isToday: grid.sameDay(day, grid.today)
                readonly property bool isSelected: grid.sameDay(day, grid.selected)
                readonly property bool marked: grid.markedDays !== null && grid.markedDays[Qt.formatDate(day, "yyyy-MM-dd")] === true

                width: grid.cellWidth
                height: grid.cellHeight
                radius: grid.theme.itemRadius
                color: isSelected ? grid.theme.accent : (dayMouse.containsMouse ? grid.theme.surfaceAlt : "transparent")
                border.width: isToday && !isSelected ? 1 : 0
                border.color: grid.theme.accent

                Text {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    color: cell.isSelected ? grid.theme.base : (cell.inMonth ? grid.theme.text : grid.theme.overlay)
                    font.family: grid.theme.fontFamily
                    font.pixelSize: grid.theme.fontSizeSmall
                    font.bold: cell.isToday
                }

                Rectangle {
                    objectName: "eventDot"

                    width: 4
                    height: 4
                    radius: 2
                    visible: cell.marked
                    color: cell.isSelected ? grid.theme.base : (cell.inMonth ? grid.theme.accent : grid.theme.overlay)
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: 3
                    }
                }

                MouseArea {
                    id: dayMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: grid.dayClicked(parent.day)
                    onDoubleClicked: grid.dayDoubleClicked(parent.day)
                }
            }
        }
    }
}
