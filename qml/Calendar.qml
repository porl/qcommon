// Drop-down calendar, opened from the clock. A month grid with prev/next
// navigation; clicking a day selects it, and clicking the selected day again
// (or double-clicking) opens the configured calendar app for that date —
// `QSHELL_CALENDAR` is a shell command template and `{date}` is replaced with
// the ISO date (apps that ignore the argument simply open as usual).
//
// Two optional commands feed the rest:
//   QSHELL_CALENDAR_AGENDA   the selected day's agenda, shown under the grid
//   QSHELL_CALENDAR_DAYS     ISO dates (first token per line) that get a dot
// Both are shell templates with {date}/{start}/{end} substituted, re-run when
// the popout opens, the selection changes or the month changes, and polled
// while it is open (QSHELL_CALENDAR_REFRESH seconds, default 300, 0 = only on
// the events above). With neither set the calendar is just the grid — which is
// the greeter's case, so the login screen stays inert.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "CalendarAgenda.js" as Agenda

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

    property int shownYear: today.getFullYear()
    property int shownMonth: today.getMonth()
    property date selected: today
    readonly property date today: {
        var d = new Date();
        d.setHours(0, 0, 0, 0);
        return d;
    }

    readonly property string agendaTemplate: Quickshell.env("QSHELL_CALENDAR_AGENDA") || ""
    readonly property string daysTemplate: Quickshell.env("QSHELL_CALENDAR_DAYS") || ""
    // Seconds between refreshes while the popout is open; 0 disables polling.
    readonly property int refreshSeconds: {
        var parsed = parseInt(Quickshell.env("QSHELL_CALENDAR_REFRESH") || "300", 10);
        return isNaN(parsed) || parsed < 0 ? 300 : parsed;
    }
    // The last query's lines (kept while a reload runs) and, when there is
    // nothing to show, its muted hint.
    property var agendaLines: []
    property string agendaHint: ""
    property var markedDays: null

    readonly property int agendaMaxLines: 6
    readonly property real agendaMaxHeight: Math.round(theme.fontSizeSmall * 1.5) * agendaMaxLines

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

    function nextDay(d): date {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
    }

    // Select a day and follow it with the shown month, so keyboard navigation
    // can walk across month and year boundaries.
    function selectDay(d): void {
        selected = d;
        shownYear = d.getFullYear();
        shownMonth = d.getMonth();
    }

    function selectRelative(days): void {
        selectDay(new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + days));
    }

    function refreshAgenda(): void {
        if (agendaTemplate.length === 0)
            return;
        agendaProcess.run(["sh", "-c", Agenda.substitute(agendaTemplate, selected, nextDay(selected))]);
    }

    // The dots cover the whole visible grid, adjacent-month days included.
    function refreshDays(): void {
        if (daysTemplate.length === 0)
            return;
        daysProcess.run(["sh", "-c", Agenda.substitute(daysTemplate, monthGrid.dayAt(0), monthGrid.dayAt(monthGrid.rows * 7))]);
    }

    function refreshAll(): void {
        refreshAgenda();
        refreshDays();
    }

    function applyAgenda(output, exitCode): void {
        var result = Agenda.agendaResult(output, exitCode);
        agendaLines = result.lines;
        agendaHint = result.hint;
    }

    function applyDays(output, exitCode): void {
        // A failed query is not "no events": keep the last dots.
        if (exitCode !== 0)
            return;
        markedDays = Agenda.markerDays(output);
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Left)
            selectRelative(-1);
        else if (event.key === Qt.Key_Right)
            selectRelative(1);
        else if (event.key === Qt.Key_Up)
            selectRelative(-7);
        else if (event.key === Qt.Key_Down)
            selectRelative(7);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            openApp(selected);
        else if (event.key === Qt.Key_Escape)
            dismissRequested();
        else
            return;
        event.accepted = true;
    }

    // A command whose output and exit code are wanted together. Quickshell
    // ends the stdout stream inside the same handler that emits `exited`, and
    // before it, so the output is collected on stream finish and the result is
    // applied on exit (which also means the exit code is never a run behind).
    // A request that arrives mid-run is kept (the newest wins and older ones
    // are dropped), so a held arrow key coalesces instead of killing queries
    // and mixing up their signals.
    component CommandRunner: Process {
        id: runner

        signal done(string output, int exitCode)

        property int exitCode: 0
        property bool collected: false
        property string collectedText: ""
        property var queued: null

        function run(command): void {
            if (running) {
                queued = command;
                return;
            }
            exec(command);
        }

        function applyIfReady(): void {
            if (!collected || running)
                return;
            collected = false;
            runner.done(collectedText, exitCode);
            if (queued !== null) {
                var next = queued;
                queued = null;
                exec(next);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                runner.collectedText = text;
                runner.collected = true;
            }
        }
        onExited: (code, status) => {
            runner.exitCode = code;
            runner.applyIfReady();
        }
        onStarted: {
            runner.collected = false;
            runner.collectedText = "";
        }
    }

    CommandRunner {
        id: agendaProcess

        onDone: (output, exitCode) => calendar.applyAgenda(output, exitCode)
    }

    CommandRunner {
        id: daysProcess

        onDone: (output, exitCode) => calendar.applyDays(output, exitCode)
    }

    Timer {
        interval: calendar.refreshSeconds * 1000
        running: calendar.open && calendar.refreshSeconds > 0 && (calendar.agendaTemplate.length > 0 || calendar.daysTemplate.length > 0)
        repeat: true
        onTriggered: calendar.refreshAll()
    }

    onOpenChanged: {
        if (open) {
            refreshAll();
            keyScope.forceActiveFocus();
        }
    }
    onSelectedChanged: refreshAgenda()
    onShownMonthChanged: refreshDays()
    onShownYearChanged: refreshDays()

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
    // Keyboard while open, released as soon as it closes: arrow keys walk the
    // grid and Enter picks the day (see handleKey).
    WlrLayershell.keyboardFocus: calendar.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => calendar.handleKey(event)

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

                MonthGrid {
                    id: monthGrid

                    width: parent.width
                    theme: calendar.theme
                    shownYear: calendar.shownYear
                    shownMonth: calendar.shownMonth
                    weekStart: calendar.weekStart
                    selected: calendar.selected
                    markedDays: calendar.markedDays
                    onDayClicked: day => {
                        if (calendar.sameDay(day, calendar.selected))
                            calendar.openApp(day);
                        else
                            calendar.selected = day;
                    }
                    onDayDoubleClicked: day => calendar.openApp(day)
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    visible: calendar.agendaTemplate.length > 0
                    color: calendar.theme.border
                }

                Text {
                    width: parent.width
                    visible: calendar.agendaTemplate.length > 0 && calendar.agendaLines.length === 0 && calendar.agendaHint.length > 0
                    text: calendar.agendaHint
                    color: calendar.theme.overlay
                    font.family: calendar.theme.fontFamily
                    font.pixelSize: calendar.theme.fontSizeSmall
                }

                Flickable {
                    id: agendaScroll

                    width: parent.width
                    height: Math.min(agendaColumn.implicitHeight, calendar.agendaMaxHeight)
                    visible: calendar.agendaLines.length > 0
                    contentHeight: agendaColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: agendaColumn

                        width: agendaScroll.width
                        spacing: 3

                        Repeater {
                            model: calendar.agendaLines

                            Text {
                                required property string modelData

                                width: agendaColumn.width
                                text: modelData
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                color: calendar.theme.subtext
                                font.family: calendar.theme.fontFamily
                                font.pixelSize: calendar.theme.fontSizeSmall
                            }
                        }
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
