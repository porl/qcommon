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
}
