import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Hyprland
import "NightSkySim.js" as Sim

// The city as a wallpaper: one full-screen background layer surface per screen,
// with the policy for when it is shown and when it animates. Shared by the
// session shell and the greeter so both draw the same city.
//
// The mode and the state machine live in NightSkySim.js (and are unit-tested
// there); this item only wires them to real signals — idle, battery, fullscreen
// — and to the layer shell. It never takes pointer or keyboard input.
Item {
    id: root

    property var theme

    // Sim.MODE_ALWAYS / MODE_IDLE / MODE_GREETER / MODE_OFF
    property int mode: Sim.MODE_ALWAYS
    // Set by the greeter so MODE_GREETER and the state snapshot are meaningful.
    property bool isGreeter: false
    property bool pauseOnBattery: false

    // Pan speed (logical px/s) for the near layer; slower on battery. The sky
    // repaint rate controls the star twinkle.
    property real panSpeed: onBattery ? 0.5 : 1
    property int fps: onBattery ? 6 : 12
    property bool meteorsEnabled: true
    property bool meteorShowers: true
    property bool buildingsEnabled: true
    property bool missileCommand: false
    property bool antialias: true
    property int seed: 1
    // Seconds of no input before MODE_IDLE shows the city.
    property int idleTimeout: 90

    readonly property bool onBattery: UPower.onBattery
    readonly property bool fullscreen: _anyFullscreen()
    readonly property bool idle: idleMonitor.isIdle
    readonly property var _state: ({
            isGreeter: isGreeter,
            idle: idle,
            onBattery: onBattery,
            fullscreen: fullscreen,
            pauseOnBattery: pauseOnBattery
        })
    readonly property bool show: Sim.shouldShow(mode, _state)
    readonly property bool animate: Sim.shouldAnimate(mode, _state)

    // Per screen: a distinct skyline per monitor, and the fullscreen pause is per
    // monitor (a fullscreen window on one screen should not freeze the others).
    function _screenFullscreen(screen): bool {
        var monitors = Hyprland.monitors ? Hyprland.monitors.values : null;
        if (!monitors || !screen)
            return false;
        for (var i = 0; i < monitors.length; ++i) {
            if (monitors[i].name !== screen.name)
                continue;
            var ws = monitors[i].activeWorkspace;
            return !!(ws && ws.hasFullscreen);
        }
        return false;
    }

    function _stateFor(screen): var {
        return {
            isGreeter: isGreeter,
            idle: idle,
            onBattery: onBattery,
            fullscreen: _screenFullscreen(screen),
            pauseOnBattery: pauseOnBattery
        };
    }

    // Stable per-monitor seed, from the output name, so each screen gets its own
    // skyline (and it does not change between sessions).
    function _seedFor(screen): int {
        var name = screen ? ("" + screen.name) : "";
        var h = 0;
        for (var i = 0; i < name.length; ++i)
            h = (h * 31 + name.charCodeAt(i)) | 0;
        return seed + Math.abs(h) % 1000;
    }

    // The first screen's city, for diagnostics (grabFirst) and tests.
    property var _primarySkyline: null

    function grabFirst(path): bool {
        if (!_primarySkyline)
            return false;
        _primarySkyline.grabToImage(function (res) {
            res.saveToFile(path);
        }, Qt.size(_primarySkyline.width, _primarySkyline.height));
        return true;
    }

    IdleMonitor {
        id: idleMonitor

        // Only the idle mode needs the idle signal.
        enabled: root.mode === Sim.MODE_IDLE
        timeout: root.idleTimeout
        respectInhibitors: true
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-nightsky"
            visible: root.show

            NightSky {
                id: skyline

                anchors.fill: parent
                theme: root.theme
                running: Sim.shouldAnimate(root.mode, root._stateFor(modelData))
                panSpeed: root.panSpeed
                fps: root.fps
                meteorsEnabled: root.meteorsEnabled
                meteorShowers: root.meteorShowers
                buildingsEnabled: root.buildingsEnabled
                missileCommand: root.missileCommand
                antialias: root.antialias
                seed: root._seedFor(modelData)

                Component.onCompleted: {
                    if (root._primarySkyline === null)
                        root._primarySkyline = skyline;
                }
            }
        }
    }

    function _anyFullscreen(): bool {
        var monitors = Hyprland.monitors ? Hyprland.monitors.values : null;
        if (!monitors)
            return false;
        for (var i = 0; i < monitors.length; ++i) {
            var ws = monitors[i].activeWorkspace;
            if (ws && ws.hasFullscreen)
                return true;
        }
        return false;
    }
}
