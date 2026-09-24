import QtQuick

QtObject {
    readonly property color base: "#000000"
    readonly property color backdrop: "#9911111b"
    // Cards are black (the shell no longer blurs them); the border keeps them
    // from disappearing into a dark desktop.
    readonly property color surface: "#e6000000"
    readonly property color surfaceAlt: "#45475a"
    // Card borders: brighter than surfaceAlt so cards read on a black desktop.
    readonly property color border: "#6c7086"
    readonly property color bar: "#cc000000"

    readonly property color text: "#cdd6f4"
    readonly property color subtext: "#bac2de"
    readonly property color overlay: "#6c7086"
    readonly property color accent: "#89b4fa"
    readonly property color danger: "#f38ba8"

    readonly property int radius: 16
    readonly property int itemRadius: 8
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    // Type scale: base for primary UI, small for secondary, tiny for captions.
    readonly property int fontSize: 16
    readonly property int fontSizeSmall: 14
    readonly property int fontSizeTiny: 12
    // Tray/status icon size. Larger than the text base so icons read at a
    // glance; both the bar and the overflow grid use it so they stay matched.
    readonly property int trayIconSize: 20
}
