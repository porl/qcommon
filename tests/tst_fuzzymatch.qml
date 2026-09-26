import QtQuick
import QtTest
import "../qml/FuzzyMatch.js" as FuzzyMatch

// The fuzzy matcher behind the launcher's ranking and the session menu's
// type-to-select. The menu-shaped list keeps the expectations readable.
TestCase {
    name: "FuzzyMatch"

    readonly property var menu: [
        { label: "Lock", action: "lock" },
        { label: "Log out", action: "logout" },
        { label: "Suspend", action: "suspend" },
        { label: "Hibernate", action: "hibernate" },
        { label: "Restart", action: "reboot" },
        { label: "Shut down", action: "poweroff" },
        { label: "Cancel", action: "cancel" }
    ]

    function test_score_is_a_subsequence() {
        verify(FuzzyMatch.score("re", "Restart") >= 0);
        verify(FuzzyMatch.score("rst", "Restart") >= 0);
        verify(FuzzyMatch.score("RE", "Restart") >= 0);
        compare(FuzzyMatch.score("zz", "Restart"), -1);
        // The space is just a skipped character; only a letter breaks the run.
        verify(FuzzyMatch.score("shutdown", "Shut down") >= 0);
        verify(FuzzyMatch.score("shut down", "Shut down") >= 0);
        compare(FuzzyMatch.score("shutdownz", "Shut down"), -1);
        compare(FuzzyMatch.score("", "Restart"), -1);
    }

    function test_score_rewards_consecutive_and_word_start() {
        // Both are subsequences of "shut down", but Suspend fits them adjacently.
        verify(FuzzyMatch.score("su", "Suspend") > FuzzyMatch.score("su", "Shut down"));
        // A word start beats the same letter mid-word.
        verify(FuzzyMatch.score("h", "Hibernate") > FuzzyMatch.score("h", "Shut down"));
        // Equal-length haystacks, the letter after a space in one: that is the
        // word-start bonus alone.
        verify(FuzzyMatch.score("b", "a b") > FuzzyMatch.score("b", "axb"));
        // Equal-length haystacks, the letters adjacent in one: that is the
        // consecutive-run bonus alone.
        verify(FuzzyMatch.score("ab", "abx") > FuzzyMatch.score("ab", "axb"));
        // A late match scores worse than an early one.
        verify(FuzzyMatch.score("l", "Lock") > FuzzyMatch.score("l", "Cancel"));
    }

    function test_best_index_selects_menu_rows() {
        compare(FuzzyMatch.bestIndex(menu, "lo"), 0);
        compare(FuzzyMatch.bestIndex(menu, "log"), 1);
        compare(FuzzyMatch.bestIndex(menu, "su"), 2);
        compare(FuzzyMatch.bestIndex(menu, "sus"), 2);
        compare(FuzzyMatch.bestIndex(menu, "h"), 3);
        compare(FuzzyMatch.bestIndex(menu, "res"), 4);
        compare(FuzzyMatch.bestIndex(menu, "sh"), 5);
        compare(FuzzyMatch.bestIndex(menu, "shu"), 5);
        compare(FuzzyMatch.bestIndex(menu, "ca"), 6);
    }

    function test_best_index_without_a_match() {
        compare(FuzzyMatch.bestIndex(menu, "zz"), -1);
        compare(FuzzyMatch.bestIndex(menu, ""), -1);
        compare(FuzzyMatch.bestIndex([], "a"), -1);
    }

    function test_best_index_tie_goes_to_the_earlier_item() {
        var items = [
            { label: "Same" },
            { label: "Same" }
        ];
        compare(FuzzyMatch.bestIndex(items, "sa"), 0);
    }

    function test_best_index_skips_items_without_the_field() {
        var items = [
            { action: "broken" },
            { label: "Cancel" }
        ];
        compare(FuzzyMatch.bestIndex(items, "ca"), 1);

        var named = [
            { name: "alpha" },
            { name: "beta" }
        ];
        compare(FuzzyMatch.bestIndex(named, "be", "name"), 1);
        compare(FuzzyMatch.bestIndex(named, "be"), -1);
    }
}
