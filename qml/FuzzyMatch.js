.pragma library

// Fuzzy matching for type-to-select and type-to-filter UIs. Pure (no QML
// types) so qmltestrunner pins the behaviour.

// Bonuses consecutive characters and word starts; penalises late and long
// haystacks. Returns -1 when the query is empty or not a subsequence.
function score(needle, haystack) {
    if (!needle || needle.length === 0 || !haystack)
        return -1;
    var text = haystack.toLowerCase();
    needle = needle.toLowerCase();
    var from = 0;
    var total = 0;
    var streak = 0;
    var first = -1;
    for (var i = 0; i < needle.length; i++) {
        var at = text.indexOf(needle.charAt(i), from);
        if (at === -1)
            return -1;
        if (first === -1)
            first = at;
        streak = at === from ? streak + 1 : 0;
        total += 1 + streak;
        var before = at === 0 ? "" : text.charAt(at - 1);
        if (before === "" || before === " " || before === "-" || before === "_")
            total += 3;
        from = at + 1;
    }
    return total - first * 0.5 - text.length * 0.01;
}

// Index of the item whose `field` (default "label") scores best for the query,
// or -1 when nothing matches. Earlier items win ties, so a menu's display order
// is the tie-break. Items without a string in that field are skipped.
function bestIndex(items, query, field) {
    if (!query || query.length === 0 || !items)
        return -1;
    var key = field || "label";
    var best = -1;
    var bestScore = -1;
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        if (!item)
            continue;
        var value = item[key];
        if (typeof value !== "string")
            continue;
        var matched = score(query, value);
        if (matched > bestScore) {
            bestScore = matched;
            best = i;
        }
    }
    return best;
}
