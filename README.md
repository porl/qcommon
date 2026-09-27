# qcommon

Shared [Quickshell](https://quickshell.org) QML components for
[qshell](../qshell) (the session shell) and [qmlgreetd](../qmlgreetd) (the
greeter). The bar, its blocks and popouts, the session menu, the calendar and
the icon set live here once and are consumed by both.

The package is a QML tree at `share/qcommon/qml`. A consumer copies it into its
own QML root, so the components resolve by name through QML's implicit
directory import — there is no module path or import statement to keep in step.

## Consumers

- **qshell** merges this tree with its own `qml/` (`shell.qml`, `Launcher.qml`,
  `Notifications.qml`) and runs the bar.
- **qmlgreetd** merges it with its greeter UI, so the login screen shares the
  bar's power block, session menu and popouts.

## Components

- Primitives: `Theme` (its colours are the Mocha palette by default; pass a
  `palette` object to override the roles a consumer deploys), `Glyph`
  (hand-drawn icons), `Toggle`, `PopoutState`, `Tooltip`, `MenuRow`,
  `MenuColumn`.
- Pure JS (unit-tested): `NightSkySim` (the wallpaper's simulation and mode
  policy), `FuzzyMatch` (fuzzy scoring and best-index used by type-to-select),
  `CalendarAgenda` (the calendar's `{date}`/`{start}`/`{end}` substitution,
  output cleanup and event-dot map).
- Bar and blocks: `Bar` (`showWorkspaces` hides the Hyprland workspace strip),
  `Workspaces`, `WorkspacePreview`, `Media`, `NetworkBlock`/`NetworkPopout`,
  `BluetoothBlock`/`BluetoothPopout`, `BrightnessBlock`/`BrightnessPopout`,
  `Volume`/`VolumePopout`, `Battery`, `Power`, `Tray`/`TrayItem`/`TrayMenu`/
  `TrayOverflow`, `Calendar` and `MonthGrid` (the calendar's weekday header and
  day cells; seven columns by construction, so a fractional cell width cannot
  drop a day, a dot per day the agenda command marks, and ISO week numbers in a
  left gutter when enabled).
- Overlays: `SessionMenu` (actions are supplied by the host, so the greeter can
  omit Lock/Log out; typing fuzzy-selects a row — Enter still activates, and the
  search resets after a pause).

## Building

```
nix build
```
