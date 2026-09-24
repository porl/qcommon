// What power actions this machine supports. Quickshell 0.3.1's UPower singleton
// only exposes battery state — there is no `canSuspend` — so suspend/hibernate
// support comes from logind's CanSuspend/CanHibernate methods instead (public,
// no polkit prompt; "challenge" means the caller's session may not do it, so it
// counts as unsupported). Reboot and power-off are always offered, since logind
// allows them for an active session. Consumed by SessionMenu via the shell.
import Quickshell.Io
import QtQuick

QtObject {
    id: caps

    property bool canSuspend: false
    property bool canHibernate: false

    function allows(text) {
        return text.indexOf("\"yes\"") >= 0;
    }

    property Process suspendProbe: Process {
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanSuspend"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: caps.canSuspend = caps.allows(text)
        }
    }

    property Process hibernateProbe: Process {
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: caps.canHibernate = caps.allows(text)
        }
    }
}
