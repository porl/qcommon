import QtQuick
import QtTest
import "../qml"

// The month grid's layout and day math (qml/MonthGrid.qml). The column count
// is pinned here: the GridView this replaced derived its columns from
// width / cellWidth, and for a 260px card that product is 6.999..., so every
// week silently dropped its seventh day.
TestCase {
    name: "MonthGrid"

    // Input tests need the window exposed before they run.
    when: windowShown

    // `.visible` reads QQuickItem's *effective* visibility (ancestors
    // included), and qmltestrunner's TestCase root is invisible by default,
    // which would mask the dots' own visible bindings.
    visible: true
    width: 400
    height: 400

    Theme { id: theme }

    MonthGrid {
        id: september

        width: 260
        theme: theme
        shownYear: 2026
        shownMonth: 8 // September
        weekStart: 1 // Monday
        selected: new Date(2026, 8, 27)
    }

    MonthGrid {
        id: sundayStart

        visible: false
        width: 260
        theme: theme
        shownYear: 2026
        shownMonth: 8
        weekStart: 0 // Sunday
        selected: new Date(2026, 8, 27)
        showWeekNumbers: true
    }

    function gridItem(grid) {
        for (var i = 0; i < grid.children.length; i++) {
            if (typeof grid.children[i].columns === "number")
                return grid.children[i];
        }
        return null;
    }

    function cells(grid) {
        var dayGrid = gridItem(grid);
        verify(dayGrid !== null, "found the day grid");
        var found = [];
        for (var i = 0; i < dayGrid.children.length; i++) {
            if (dayGrid.children[i].day !== undefined)
                found.push(dayGrid.children[i]);
        }
        return found;
    }

    function iso(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function test_grid_has_seven_explicit_columns() {
        waitForRendering(september);
        compare(gridItem(september).columns, 7);
    }

    function test_seven_cells_share_each_row() {
        waitForRendering(september);
        var c = cells(september);
        compare(c.length, september.rows * 7);
        for (var i = 1; i < 7; i++)
            compare(c[i].y, c[0].y, "cell " + i + " is on the first row");
        compare(c[6].x > c[0].x, true, "the seventh cell is to the right of the first");
        compare(c[7].y > c[0].y, true, "the eighth cell starts the second row");
    }

    function test_september_2026_rows_and_edges() {
        waitForRendering(september);
        compare(september.rows, 5);
        compare(iso(september.dayAt(0)), "2026-08-31");
        compare(iso(september.dayAt(1)), "2026-09-01");
        // The last day of the month is in the grid (it was clipped away when
        // a week lost its seventh cell).
        compare(iso(september.dayAt(30)), "2026-09-30");
        compare(september.dayAt(30).getMonth(), september.shownMonth);
    }

    function test_six_row_month() {
        compare(august.rows, 6);
        compare(iso(august.dayAt(0)), "2026-07-27");
    }

    function test_four_row_month() {
        compare(february.rows, 4);
        compare(iso(february.dayAt(0)), "2027-02-01");
    }

    function test_sunday_week_start_offsets_the_grid() {
        compare(sundayStart.rows, 5);
        compare(iso(sundayStart.dayAt(0)), "2026-08-30");
    }

    function cellOn(grid, y, m, d) {
        var c = cells(grid);
        var wanted = new Date(y, m, d);
        for (var i = 0; i < c.length; i++) {
            if (grid.sameDay(c[i].day, wanted))
                return c[i];
        }
        return null;
    }

    function test_event_dots_mark_their_days() {
        waitForRendering(withMarkers);
        var c = cellOn(withMarkers, 2026, 8, 27);
        verify(c !== null, "found 27 September");
        compare(c.marked, true);
        var dot = findChild(c, "eventDot");
        verify(dot !== null, "found the dot");
        compare(dot.visible, true);
        var plain = cellOn(withMarkers, 2026, 8, 26);
        compare(plain.marked, false);
        compare(findChild(plain, "eventDot").visible, false);
    }

    function test_event_dots_reach_adjacent_month_days() {
        waitForRendering(withMarkers);
        // 2026-08-31 is the first cell of the September grid.
        compare(cellOn(withMarkers, 2026, 7, 31).marked, true);
        compare(cellOn(withMarkers, 2026, 8, 30).marked, false);
    }

    function test_no_dots_without_markers() {
        waitForRendering(september);
        compare(cells(september)[0].marked, false);
    }

    function weekTexts(grid) {
        var column = findChild(grid, "weekNumbers");
        verify(column !== null, "found the week-number column");
        var texts = [];
        for (var i = 0; i < column.children.length; i++) {
            var child = column.children[i];
            if (typeof child.text === "string" && child.height === grid.cellHeight)
                texts.push(child);
        }
        return texts;
    }

    function test_iso_week_numbers() {
        // Weeks start Monday and week 1 is the week of 4 January.
        compare(september.isoWeek(new Date(2026, 0, 1)), 1);
        compare(september.isoWeek(new Date(2025, 11, 29)), 1);
        compare(september.isoWeek(new Date(2026, 0, 4)), 1);
        compare(september.isoWeek(new Date(2026, 0, 5)), 2);
        // 2026 has 53 weeks; 2027-W01 starts Monday 4 January.
        compare(september.isoWeek(new Date(2026, 11, 31)), 53);
        compare(september.isoWeek(new Date(2027, 0, 3)), 53);
        compare(september.isoWeek(new Date(2027, 0, 4)), 1);
        compare(september.isoWeek(new Date(2005, 0, 1)), 53);
        compare(september.isoWeek(new Date(2020, 11, 31)), 53);
    }

    function test_week_labels_follow_the_rows() {
        waitForRendering(withWeeks);
        compare(withWeeks.weekNumberAt(0), 36);
        compare(withWeeks.weekNumberAt(4), 40);
        compare(withWeeks.weekLabelAt(0), "w36");
        compare(withWeeks.weekLabelAt(4), "w40");
    }

    function test_week_labels_use_the_majority_week_under_a_sunday_start() {
        // The row starts on Sunday 30 August; its Wednesday is in the same ISO
        // week as the Monday-to-Saturday part the row mostly covers.
        compare(sundayStart.weekNumberAt(0), 36);
        compare(sundayStart.weekNumberAt(4), 40);
    }

    function test_week_labels_handle_a_53_week_year() {
        compare(december.weekLabelAt(december.rows - 1), "w53");
    }

    function test_week_format_template() {
        compare(withWeeks.weekLabelFor(7), "w7");
        compare(customFormat.weekLabelAt(0), "36");
        verify(customFormat.weekGutter < withWeeks.weekGutter, "a shorter format needs a narrower gutter");
    }

    function test_week_numbers_render_down_the_gutter() {
        waitForRendering(withWeeks);
        var texts = weekTexts(withWeeks);
        compare(texts.length, withWeeks.rows);
        compare(texts[0].text, "w36");
        compare(texts[4].text, "w40");
        // smaller and dimmer than the day numbers
        compare(texts[0].font.pixelSize, theme.fontSizeTiny);
        compare(texts[0].color, theme.overlay);
        compare(texts[0].x, 0);
        compare(texts[0].width, withWeeks.weekGutter - 4);
    }

    function test_week_numbers_shrink_the_day_cells() {
        waitForRendering(withWeeks);
        verify(withWeeks.weekGutter > 0, "the gutter is reserved");
        compare(withWeeks.cellWidth, (withWeeks.width - withWeeks.weekGutter) / 7);
        compare(gridItem(withWeeks).x, withWeeks.weekGutter);
        var c = cells(withWeeks);
        compare(c[0].x, 0, "the first day cell starts the day area");
        verify(c[6].x + c[6].width <= withWeeks.dayAreaWidth + 0.01, "seven cells fit the day area");
    }

    function test_week_numbers_off_leaves_the_grid_alone() {
        waitForRendering(september);
        compare(september.weekGutter, 0);
        compare(september.cellWidth, september.width / 7);
        compare(findChild(september, "weekNumbers").visible, false);
        compare(gridItem(september).x, 0);
        compare(gridItem(september).width, september.width);
    }

    // No click test: qmltestrunner's offscreen platform does not deliver
    // synthetic mouse events (a bare MouseArea with `when: windowShown` fails
    // the same way), so the click wiring is driven on a machine instead.

    MonthGrid {
        id: august

        visible: false
        theme: theme
        shownYear: 2026
        shownMonth: 7 // August
        weekStart: 1
    }

    MonthGrid {
        id: february

        visible: false
        theme: theme
        shownYear: 2027
        shownMonth: 1 // February
        weekStart: 1
    }

    MonthGrid {
        id: withMarkers

        width: 260
        theme: theme
        shownYear: 2026
        shownMonth: 8 // September
        weekStart: 1 // Monday
        markedDays: ({
            "2026-09-27": true,
            "2026-08-31": true
        })
    }

    MonthGrid {
        id: withWeeks

        width: 260
        theme: theme
        shownYear: 2026
        shownMonth: 8 // September
        weekStart: 1 // Monday
        showWeekNumbers: true
    }

    MonthGrid {
        id: customFormat

        visible: false
        width: 260
        theme: theme
        shownYear: 2026
        shownMonth: 8 // September
        weekStart: 1
        showWeekNumbers: true
        weekFormat: "{week}"
    }

    MonthGrid {
        id: december

        visible: false
        width: 260
        theme: theme
        shownYear: 2026
        shownMonth: 11 // December
        weekStart: 1
        showWeekNumbers: true
    }
}
