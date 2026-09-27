import QtQuick

// The look of every qcommon component. The palette is data: a consumer that
// deploys or lets the user choose a theme passes one in (qmlgreetd reads it from
// its config file); every key falls back to the Mocha value below, so a partial
// palette is fine. Values are used as-is - validate them at the boundary, since
// a bad colour only reaches QML's colour conversion and warns.
QtObject {
    // Colour overrides by Theme property name, e.g. { accent: "#f38ba8" }.
    property var palette: null

    readonly property color base: colour("base", "#000000")
    readonly property color backdrop: colour("backdrop", "#9911111b")
    // Cards are black; the border keeps them from disappearing into a dark
    // desktop.
    readonly property color surface: colour("surface", "#e6000000")
    readonly property color surfaceAlt: colour("surfaceAlt", "#45475a")
    // Card borders: brighter than surfaceAlt so cards read on a black desktop.
    readonly property color border: colour("border", "#6c7086")
    readonly property color bar: colour("bar", "#cc000000")

    readonly property color text: colour("text", "#cdd6f4")
    readonly property color subtext: colour("subtext", "#bac2de")
    readonly property color overlay: colour("overlay", "#6c7086")
    readonly property color accent: colour("accent", "#89b4fa")
    readonly property color danger: colour("danger", "#f38ba8")

    // The night-sky wallpaper's palette. Kept here so the session shell and the
    // greeter draw the same sky, and so it follows the theme like everything
    // else. `buildingGlow` is the city glow (shaded by the renderer into a lit
    // face and a shadowed one); star and moon are the sky.
    readonly property color skyTop: colour("skyTop", "#04040a")
    readonly property color skyBottom: colour("skyBottom", "#12122a")
    readonly property color buildingGlow: colour("buildingGlow", "#f9e2af")
    readonly property color starGlow: colour("starGlow", "#dfe6ff")
    readonly property color moonGlow: colour("moonGlow", "#f5f0d8")
    // Missile-command mode: interceptors keep the meteor shape but a red tail,
    // and both kinds of impact flash warm.
    readonly property color missileTrail: colour("missileTrail", "#ff6b5e")
    readonly property color explosionGlow: colour("explosionGlow", "#ffd9a0")

    readonly property int radius: 16
    readonly property int itemRadius: 8
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    // Type scale: base for primary UI, small for secondary, tiny for captions,
    // micro for labels that must recede behind them (the week-number gutter).
    readonly property int fontSize: 16
    readonly property int fontSizeSmall: 14
    readonly property int fontSizeTiny: 12
    readonly property int fontSizeMicro: 10
    // Tray/status icon size. Larger than the text base so icons read at a
    // glance; both the bar and the overflow grid use it so they stay matched.
    readonly property int trayIconSize: 20

    function colour(key, fallback) {
        return palette && typeof palette[key] === "string" ? palette[key] : fallback;
    }
}
