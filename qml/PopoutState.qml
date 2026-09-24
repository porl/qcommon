// Reusable open/close behaviour for bar popouts:
//   - hovering the bar block opens after a delay and closes after a delay once
//     the pointer leaves both the block and the popout;
//   - clicking (or scrolling) opens immediately and *pins* it, so it then only
//     closes when focus is lost (a click elsewhere).
// The workspace preview deliberately does not use this: it always closes as
// soon as the pointer leaves.
import QtQuick

QtObject {
    id: state

    property bool open: false
    property bool pinned: false
    property bool anchorHovered: false
    property bool contentHovered: false

    property int openDelay: 350
    property int closeDelay: 300

    property Timer openTimer: Timer {
        interval: state.openDelay
        onTriggered: state.open = true
    }

    property Timer closeTimer: Timer {
        interval: state.closeDelay
        onTriggered: if (!state.anchorHovered && !state.contentHovered && !state.pinned)
            state.open = false
    }

    function anchorEntered(): void {
        closeTimer.stop();
        anchorHovered = true;
        if (!open)
            openTimer.restart();
    }

    function anchorExited(): void {
        openTimer.stop();
        anchorHovered = false;
        if (!pinned)
            closeTimer.restart();
    }

    function contentEntered(): void {
        closeTimer.stop();
        contentHovered = true;
        open = true;
    }

    function contentExited(): void {
        contentHovered = false;
        if (!pinned)
            closeTimer.restart();
    }

    // Click: open now and stay open until focus is lost.
    function activate(): void {
        openTimer.stop();
        closeTimer.stop();
        open = true;
        pinned = true;
    }

    // Scroll: open now, but keep the hover close behaviour.
    function hoverActivate(): void {
        openTimer.stop();
        closeTimer.stop();
        open = true;
    }

    function focusLost(): void {
        if (pinned)
            close();
    }

    function close(): void {
        openTimer.stop();
        closeTimer.stop();
        open = false;
        pinned = false;
    }
}
