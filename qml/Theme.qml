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

    // The night-sky wallpaper's palette. Kept here so the session shell and the
    // greeter draw the same sky, and so it follows the theme like everything
    // else. `buildingGlow` is the city glow (shaded by the renderer into a lit
    // face and a shadowed one); star and moon are the sky.
    readonly property color skyTop: "#04040a"
    readonly property color skyBottom: "#12122a"
    readonly property color buildingGlow: "#f9e2af"
    readonly property color starGlow: "#dfe6ff"
    readonly property color moonGlow: "#f5f0d8"
    // Missile-command mode: interceptors keep the meteor shape but a red tail,
    // and both kinds of impact flash warm.
    readonly property color missileTrail: "#ff6b5e"
    readonly property color explosionGlow: "#ffd9a0"

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
