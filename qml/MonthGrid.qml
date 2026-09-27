// A month's weekday header and day cells. The days are built as explicit rows
// of seven rather than a wrapping view, so a fractional cell width can never
// collapse a column (a GridView's column count comes from width / cellWidth,
// which floors to six for e.g. 260 / (260 / 7)). Pure QtQuick apart from Theme,
// so qmltestrunner pins the layout; clicking emits the day and the consumer
// decides what a click means.
//
// With `showWeekNumbers` the rows carry an ISO 8601 week number in a left
// gutter (the numbers of the week each row mostly covers), rendered with
// `weekFormat`, which takes a `{week}` placeholder.
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
    property bool showWeekNumbers: false
    property string weekFormat: "W{week}"

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
    // The gutter is sized to the widest label the format can produce (week
    // 53), so a custom format does not need a hard-coded width.
    readonly property real weekGutter: showWeekNumbers ? Math.ceil(weekMetrics.advanceWidth) + 8 : 0
    readonly property real dayAreaWidth: width - weekGutter
    readonly property real cellWidth: dayAreaWidth / 7

    signal dayClicked(date day)
    signal dayDoubleClicked(date day)

    function dayAt(index): date {
        var first = new Date(shownYear, shownMonth, 1);
        return new Date(shownYear, shownMonth, 1 - firstOffset + index);
    }

    function sameDay(a, b): bool {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // ISO 8601 week number: weeks start Monday, week 1 is the week of 4
    // January. UTC arithmetic so DST cannot shift a day.
    function isoWeek(d): int {
        var utc = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate());
        var mondayIndex = (new Date(utc).getUTCDay() + 6) % 7;
        var thursday = utc + (3 - mondayIndex) * 86400000;
        var year = new Date(thursday).getUTCFullYear();
        var jan4 = Date.UTC(year, 0, 4);
        var jan4MondayIndex = (new Date(jan4).getUTCDay() + 6) % 7;
        var week1Monday = jan4 - jan4MondayIndex * 86400000;
        return Math.round((thursday - week1Monday) / (7 * 86400000)) + 1;
    }

    // A row's week is the ISO week of its fourth day: Thursday on a Monday
    // start, Wednesday on a Sunday start (which is in the ISO week of the
    // row's Monday-to-Saturday part). Either way that is the week the row
    // mostly covers.
    function weekNumberAt(row): int {
        return isoWeek(dayAt(row * 7 + 3));
    }

    function weekLabelFor(week): string {
        return ("" + weekFormat).replace(/\{week\}/g, "" + week);
    }

    function weekLabelAt(row): string {
        return weekLabelFor(weekNumberAt(row));
    }

    implicitWidth: cellWidth * 7 + weekGutter
    implicitHeight: header.height + days.height
    // A container: give it real bounds so hit-testing and the card's Column
    // both see the content (implicitHeight alone is only a hint).
    height: implicitHeight

    TextMetrics {
        id: weekMetrics

        font.family: grid.theme.fontFamily
        font.pixelSize: grid.theme.fontSizeMicro
        text: grid.weekLabelFor(53)
    }

    Row {
        id: header

        x: grid.weekGutter
        width: grid.dayAreaWidth

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
        x: grid.weekGutter
        width: grid.dayAreaWidth
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

    Column {
        id: weekNumbers

        objectName: "weekNumbers"

        visible: grid.showWeekNumbers
        anchors.top: days.top
        x: 0
        width: Math.max(0, grid.weekGutter - 4)

        Repeater {
            model: grid.rows

            Text {
                required property int index

                width: weekNumbers.width
                height: grid.cellHeight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: grid.weekLabelAt(index)
                color: grid.theme.overlay
                font.family: grid.theme.fontFamily
                font.pixelSize: grid.theme.fontSizeMicro
            }
        }
    }
}
