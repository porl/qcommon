.pragma library

// Placeholder substitution and output handling for the drop-down calendar's
// agenda and its event dots. Pure (no QML types), so qmltestrunner pins the
// behaviour; the component runs the commands and hands the raw text in.

// yyyy-MM-dd, local time.
function isoDate(d) {
    var month = d.getMonth() + 1;
    var day = d.getDate();
    return d.getFullYear() + "-" + (month < 10 ? "0" : "") + month + "-" + (day < 10 ? "0" : "") + day;
}

// {date} and {start} are the range's first day; {end} is the day after its
// last. Unknown placeholders are left alone.
function substitute(template, start, endExclusive) {
    var first = isoDate(start);
    return ("" + template)
        .replace(/\{date\}/g, first)
        .replace(/\{start\}/g, first)
        .replace(/\{end\}/g, isoDate(endExclusive));
}

// Strip terminal escapes, normalise line endings, drop trailing whitespace and
// collapse blank runs, so raw tool output can be laid out as lines. Leading
// whitespace is kept: it is often the tool's own alignment.
function clean(raw) {
    var text = raw === undefined || raw === null ? "" : "" + raw;
    text = text.replace(/\r\n?/g, "\n");
    text = text.replace(/\u001b\][^\u0007\u001b]*(?:\u0007|\u001b\\)/g, "");
    text = text.replace(/\u001b\[[0-?]*[ -\/]*[@-~]/g, "");
    var input = text.split("\n");
    var lines = [];
    for (var i = 0; i < input.length; i++) {
        var line = input[i].replace(/[ \t]+$/, "");
        if (line === "" && (lines.length === 0 || lines[lines.length - 1] === ""))
            continue;
        lines.push(line);
    }
    while (lines.length > 0 && lines[lines.length - 1] === "")
        lines.pop();
    return lines;
}

// The agenda section's state: the tool's lines, or a muted hint when there is
// nothing to show. A non-zero exit is a failure even if it printed something.
function agendaResult(raw, exitCode) {
    if (exitCode !== 0)
        return { lines: [], hint: "Agenda unavailable" };
    var lines = clean(raw);
    if (lines.length === 0)
        return { lines: [], hint: "No events" };
    return { lines: lines, hint: "" };
}

// The event-dot map: a line whose first token is an ISO date marks that day.
// Anything else (headings, warnings, blank lines) is ignored.
function markerDays(raw) {
    var lines = clean(raw);
    var days = {};
    for (var i = 0; i < lines.length; i++) {
        var match = /^\s*(\d{4}-\d{2}-\d{2})(?=\s|$)/.exec(lines[i]);
        if (match)
            days[match[1]] = true;
    }
    return days;
}
