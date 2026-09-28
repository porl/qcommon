// Session menu: a full-screen overlay toggled by the host (the qshell bridge or
// the greeter). The overlay animates itself in QML (the backdrop fades, the card
// scales), so the compositor must not animate the layer surface too (`no_anim`
// in the Hyprland layer rules) — that would scale the whole-surface blur as a
// rectangle. `shown` drives the visuals; `visible` only maps/unmaps, a beat
// after the close animation has finished.
//
// The menu does not run anything: it emits `actionTriggered` and the host
// decides how (qshell uses hyprctl/systemctl, the greeter goes through
// qmlgreetd's power command). Which actions exist is a pure function of the
// capability flags, so the greeter can drop Lock/Log out and a machine without
// suspend support never shows Suspend.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "FuzzyMatch.js" as FuzzyMatch

PanelWindow {
    id: menu

    required property Theme theme

    // "session" for a logged-in shell, "greeter" for the login screen. The
    // defaults below are what each context can do; a host may override any.
    property string context: "session"
    property bool canLock: context === "session"
    property bool canLogout: context === "session"
    property bool canSuspend: false
    property bool canHibernate: false
    property bool canReboot: true
    property bool canPoweroff: true

    signal actionTriggered(string action)

    // Emitted when Escape dismisses the menu without running an action, so the
    // host can treat it as "back out of everything" (the greeter resets the
    // login card and closes the bar overlays with it).
    signal escaped()

    // Pure mapping from capabilities to the rows, in display order. Rebuilt
    // whenever a flag changes; `current` is clamped in the handler below.
    readonly property var items: {
        var list = [];
        if (canLock)
            list.push({ label: "Lock", action: "lock", danger: false });
        if (canLogout)
            list.push({ label: "Log out", action: "logout", danger: true });
        if (canSuspend)
            list.push({ label: "Suspend", action: "suspend", danger: false });
        if (canHibernate)
            list.push({ label: "Hibernate", action: "hibernate", danger: false });
        if (canReboot)
            list.push({ label: "Restart", action: "reboot", danger: true });
        if (canPoweroff)
            list.push({ label: "Shut down", action: "poweroff", danger: true });
        list.push({ label: "Cancel", action: "cancel", danger: false });
        return list;
    }

    visible: false
    property bool shown: false
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-session"

    property int current: 1

    // Type-to-select: printable keystrokes since the last pause, fuzzy-matched
    // against the row labels to move `current`. Enter still runs the selection,
    // so nothing here can fire an action on its own.
    property string query: ""

    // A pause ends the search, so the next keystroke starts a fresh one rather
    // than extending a stale query (a combobox's reset).
    Timer {
        id: queryTimer

        interval: 1000
        onTriggered: menu.query = ""
    }

    onItemsChanged: if (current >= items.length)
        current = Math.max(0, items.length - 1)

    function clearQuery(): void {
        queryTimer.stop();
        query = "";
    }

    function typeQuery(text: string): void {
        var next = query + text;
        var index = FuzzyMatch.bestIndex(items, next);
        if (index < 0) {
            // A key that matches nothing must not wedge the search: try it on
            // its own, and give up if even that matches nothing.
            next = text;
            index = FuzzyMatch.bestIndex(items, next);
        }
        if (index < 0) {
            clearQuery();
            return;
        }
        query = next;
        current = index;
        queryTimer.restart();
    }

    function backspaceQuery(): void {
        if (query.length === 0)
            return;
        query = query.slice(0, -1);
        var index = FuzzyMatch.bestIndex(items, query);
        if (index >= 0)
            current = index;
        if (query.length === 0)
            queryTimer.stop();
        else
            queryTimer.restart();
    }

    Timer {
        id: closeTimer

        interval: 170
        onTriggered: menu.visible = false
    }

    function open(): void {
        closeTimer.stop();
        clearQuery();
        visible = true;
        shown = true;
        scope.forceActiveFocus();
    }

    function close(): void {
        shown = false;
        closeTimer.restart();
    }

    function toggle(): void {
        if (shown)
            close();
        else
            open();
    }

    function run(action: string): void {
        if (action === "cancel") {
            close();
            return;
        }
        close();
        menu.actionTriggered(action);
    }

    Rectangle {
        anchors.fill: parent
        color: menu.theme.backdrop
        opacity: menu.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: menu.close()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 260
        height: column.implicitHeight + 32
        radius: menu.theme.radius
        color: menu.theme.surface
        border.width: 1
        border.color: menu.theme.border
        scale: menu.shown ? 1 : 0.92
        opacity: menu.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        FocusScope {
            id: scope

            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (menu.query.length > 0) {
                        menu.clearQuery();
                    } else {
                        menu.visible = false;
                        menu.escaped();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    menu.clearQuery();
                    menu.current = (menu.current + 1) % menu.items.length;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    menu.clearQuery();
                    menu.current = (menu.current + menu.items.length - 1) % menu.items.length;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    menu.run(menu.items[menu.current].action);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backspace) {
                    menu.backspaceQuery();
                    event.accepted = true;
                } else if (event.text.length > 0
                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    menu.typeQuery(event.text);
                    event.accepted = true;
                }
            }

            Column {
                id: column

                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 8

                Repeater {
                    model: menu.items

                    Rectangle {
                        required property var modelData
                        required property int index

                        width: column.width
                        height: 40
                        radius: menu.theme.itemRadius
                        color: index === menu.current
                            ? (modelData.danger ? menu.theme.danger : (modelData.action === "cancel" ? menu.theme.surfaceAlt : menu.theme.accent))
                            : (area.containsMouse ? menu.theme.surfaceAlt : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: index === menu.current && modelData.action !== "cancel" ? menu.theme.base : menu.theme.text
                            font.family: menu.theme.fontFamily
                            font.pixelSize: menu.theme.fontSize
                        }

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: menu.run(modelData.action)
                        }
                    }
                }
            }
        }
    }
}
