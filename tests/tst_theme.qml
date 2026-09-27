import QtQuick
import QtTest
import "../qml"

// Theme's palette injection: a palette overrides the roles it names and leaves
// every other role at the Mocha default, so a deployment can ship a partial
// theme. Values are validated by the consumer (see qmlgreetd's config
// resolver), not here.
TestCase {
    name: "Theme"

    Theme { id: plain }
    Theme { id: custom; palette: ({ accent: "#f38ba8", surface: "#80111111", skyTop: "#000010" }) }
    Theme { id: mutable; palette: ({ accent: "#89b4fa" }) }

    function test_defaults_without_a_palette() {
        verify(Qt.colorEqual(plain.accent, "#89b4fa"));
        verify(Qt.colorEqual(plain.surface, "#e6000000"));
        verify(Qt.colorEqual(plain.skyTop, "#04040a"));
        compare(plain.radius, 16);
        compare(plain.fontSize, 16);
        compare(plain.trayIconSize, 20);
    }

    function test_palette_overrides_named_roles_only() {
        verify(Qt.colorEqual(custom.accent, "#f38ba8"));
        verify(Qt.colorEqual(custom.surface, "#80111111"));
        verify(Qt.colorEqual(custom.skyTop, "#000010"));
        verify(Qt.colorEqual(custom.text, "#cdd6f4"));
        verify(Qt.colorEqual(custom.border, "#6c7086"));
        verify(Qt.colorEqual(custom.missileTrail, "#ff6b5e"));
    }

    function test_palette_can_be_replaced() {
        mutable.palette = { accent: "#a6e3a1" };
        verify(Qt.colorEqual(mutable.accent, "#a6e3a1"));
        verify(Qt.colorEqual(mutable.surface, "#e6000000"));
    }
}
