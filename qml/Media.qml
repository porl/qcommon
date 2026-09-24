// Now-playing block (MPRIS): the active player's track. The track expands from
// the icon on a change and collapses back after a few seconds; hovering always
// shows the full title as a tooltip. Left click toggles play/pause, middle click
// is previous, right click is next. Hidden when no player has a track.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: media

    required property Theme theme
    property int maxLabelWidth: 220
    // Shown on a track change, then collapsed back to just the icon.
    property bool expanded: false

    // Prefer the player that is actually playing; otherwise the first one.
    readonly property var player: {
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }
    readonly property bool present: player !== null && (player.trackTitle !== "" || player.trackArtist !== "")
    readonly property string label: {
        if (!present)
            return "";
        var title = player.trackTitle || "";
        var artist = player.trackArtist || "";
        return artist !== "" ? artist + " – " + title : title;
    }

    visible: present
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight

    function expand(): void {
        if (!present)
            return;
        expanded = true;
        collapseTimer.restart();
    }

    onLabelChanged: expand()
    Component.onCompleted: if (present)
        expand()

    Timer {
        id: collapseTimer

        interval: 4000
        onTriggered: media.expanded = false
    }

    Tooltip {
        id: tip

        theme: media.theme
        item: media
        title: media.label
    }

    Timer {
        id: tipTimer

        interval: 600
        onTriggered: if (hover.containsMouse) tip.open = true
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            theme: media.theme
            name: media.player !== null && media.player.isPlaying ? "pause" : "play"
            color: hover.containsMouse ? media.theme.accent : media.theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: width > 0
            width: media.expanded ? Math.min(implicitWidth, media.maxLabelWidth) : 0
            elide: Text.ElideRight
            text: media.label
            color: hover.containsMouse ? media.theme.accent : media.theme.text
            font.family: media.theme.fontFamily
            font.pixelSize: media.theme.fontSizeSmall

            Behavior on width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onContainsMouseChanged: {
            if (containsMouse)
                tipTimer.restart();
            else {
                tipTimer.stop();
                tip.open = false;
            }
        }
        onClicked: mouse => {
            if (!media.player)
                return;
            if (mouse.button === Qt.MiddleButton) {
                if (media.player.canGoPrevious)
                    media.player.previous();
            } else if (mouse.button === Qt.RightButton) {
                if (media.player.canGoNext)
                    media.player.next();
            } else if (media.player.canTogglePlaying) {
                media.player.togglePlaying();
            }
        }
    }
}
