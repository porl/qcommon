import QtQuick
import QtTest
import "../qml/CalendarAgenda.js" as Agenda

// The calendar agenda's pure pieces (qml/CalendarAgenda.js): placeholder
// substitution, output cleanup, the result policy and the event-dot map.
// Calendar.qml only runs the commands and feeds the raw text in.
TestCase {
    name: "CalendarAgenda"

    function test_iso_date_pads() {
        compare(Agenda.isoDate(new Date(2026, 8, 27)), "2026-09-27");
        compare(Agenda.isoDate(new Date(2026, 0, 1)), "2026-01-01");
        compare(Agenda.isoDate(new Date(2026, 11, 31)), "2026-12-31");
    }

    function test_substitute_all_placeholders() {
        var day = new Date(2026, 8, 27);
        var next = new Date(2026, 8, 28);
        compare(Agenda.substitute("khal list {start} {end}", day, next), "khal list 2026-09-27 2026-09-28");
        compare(Agenda.substitute("agenda {date}", day, next), "agenda 2026-09-27");
        compare(Agenda.substitute("{date} {date} {start} {end}", day, next), "2026-09-27 2026-09-27 2026-09-27 2026-09-28");
    }

    function test_substitute_leaves_unknown_placeholders() {
        var day = new Date(2026, 8, 27);
        compare(Agenda.substitute("{other} {end}", day, new Date(2026, 8, 28)), "{other} 2026-09-28");
    }

    function test_substitute_crosses_month_and_year() {
        compare(Agenda.substitute("{start}..{end}", new Date(2026, 11, 31), new Date(2027, 0, 1)), "2026-12-31..2027-01-01");
    }

    function test_clean_strips_ansi_and_carriage_returns() {
        compare(Agenda.clean("\u001b[1;31mRed\u001b[0m\r\nplain\r").join("|"), "Red|plain");
        compare(Agenda.clean("sum \u001b]0;title\u0007tail").join("|"), "sum tail");
    }

    function test_clean_collapses_blank_runs() {
        compare(Agenda.clean("a\n\n\n \n\nb\n").join("|"), "a||b");
    }

    function test_clean_trims_trailing_whitespace_and_edge_blanks() {
        compare(Agenda.clean("\n\n  indented   \n\n").join("|"), "  indented");
    }

    function test_clean_of_empty_input() {
        compare(Agenda.clean("").length, 0);
        compare(Agenda.clean(undefined).length, 0);
    }

    function test_agenda_result_lines() {
        var result = Agenda.agendaResult("09:00 Standup\n\n12:00 Lunch\n", 0);
        compare(result.hint, "");
        compare(result.lines.join("|"), "09:00 Standup||12:00 Lunch");
    }

    function test_agenda_result_empty() {
        var result = Agenda.agendaResult("\n \n", 0);
        compare(result.lines.length, 0);
        compare(result.hint, "No events");
    }

    function test_agenda_result_failure() {
        var result = Agenda.agendaResult("", 127);
        compare(result.lines.length, 0);
        compare(result.hint, "Agenda unavailable");
    }

    function test_agenda_result_failure_beats_output() {
        var result = Agenda.agendaResult("partial output", 1);
        compare(result.lines.length, 0);
        compare(result.hint, "Agenda unavailable");
    }

    function test_marker_days_first_token_is_a_date() {
        var days = Agenda.markerDays("2026-09-27\n2026-09-27 Standup\n 2026-10-01  Two\nnot a date\n2026-09-270\n2026-09-290\n");
        compare(days["2026-09-27"], true);
        compare(days["2026-10-01"], true);
        verify(days["2026-09-29"] === undefined, "a date glued to more digits is not a marker");
        compare(Object.keys(days).length, 2);
    }

    function test_marker_days_of_empty_input() {
        compare(Object.keys(Agenda.markerDays("")).length, 0);
    }
}
