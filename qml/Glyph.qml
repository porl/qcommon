// Hand-drawn icon set: everything in the bar and the tray popouts is drawn here
// with a Canvas so it matches the bar text (rounded, consistent weight) instead
// of mixing icon-font families. `name` selects the shape; `level` and `charging`
// drive the ones that carry state (wifi strength, volume, battery).
import QtQuick

Item {
    id: glyph

    required property Theme theme
    property string name: ""
    property color color: theme.text
    property int size: theme.fontSize
    // 0-1, used by wifi (strength), volume (0 mute / .5 low / 1 high), battery.
    property real level: 1
    property bool charging: false

    readonly property real aspect: {
        if (name === "battery")
            return 1.05;
        if (name === "bluetooth")
            return 0.6;
        // These reserve room on the right for the level waves / mute cross.
        if (name === "volume" || name === "volume-low" || name === "volume-mute" || name === "mic" || name === "mic-off")
            return 1.5;
        if (name === "headphones-level" || name === "headphones-mute")
            return 1.8;
        if (name === "chevron-left" || name === "chevron-right")
            return 0.6;
        if (name === "chevron-double-left" || name === "chevron-double-right")
            return 1;
        return 1;
    }

    implicitWidth: Math.round(size * aspect)
    implicitHeight: size

    onNameChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onLevelChanged: canvas.requestPaint()
    onChargingChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: glyph.paint(getContext("2d"), width, height)
    }

    function roundedRect(ctx, x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + r);
        ctx.lineTo(x + w, y + h - r);
        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
        ctx.lineTo(x + r, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - r);
        ctx.lineTo(x, y + r);
        ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.closePath();
    }

    // The shared mute mark: one X, so the speaker, headphone and mic mute
    // states read identically. `half` is the arm length from the centre.
    function drawMuteCross(ctx, cx, cy, half, lineWidth) {
        ctx.lineWidth = lineWidth;
        ctx.beginPath();
        ctx.moveTo(cx - half, cy - half);
        ctx.lineTo(cx + half, cy + half);
        ctx.moveTo(cx + half, cy - half);
        ctx.lineTo(cx - half, cy + half);
        ctx.stroke();
    }

    // The shared level mark: sound waves opening right from `x`, the same two
    // steps the speaker uses. Drawn to the side of the device so it never
    // overlaps it, and swapped for the cross when muted.
    function drawLevelWaves(ctx, x, s, level, lineWidth) {
        if (level <= 0)
            return;
        ctx.lineWidth = lineWidth;
        ctx.beginPath();
        ctx.arc(x, 0.5 * s, 0.24 * s, -Math.PI * 0.25, Math.PI * 0.25);
        ctx.stroke();
        if (level > 0.75) {
            ctx.beginPath();
            ctx.arc(x, 0.5 * s, 0.42 * s, -Math.PI * 0.25, Math.PI * 0.25);
            ctx.stroke();
        }
    }

    function paint(ctx, w, h) {
        ctx.reset();
        ctx.fillStyle = glyph.color;
        ctx.strokeStyle = glyph.color;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        var n = glyph.name;
        if (n === "wifi")
            drawWifi(ctx, w, h);
        else if (n === "ethernet")
            drawEthernet(ctx, w, h);
        else if (n === "volume" || n === "volume-low")
            drawVolume(ctx, w, h, false);
        else if (n === "volume-mute")
            drawVolume(ctx, w, h, true);
        else if (n === "battery")
            drawBattery(ctx, w, h);
        else if (n === "power")
            drawPower(ctx, w, h);
        else if (n === "bluetooth")
            drawBluetooth(ctx, w, h);
        else if (n === "brightness")
            drawBrightness(ctx, w, h);
        else if (n === "play")
            drawPlay(ctx, w, h);
        else if (n === "pause")
            drawPause(ctx, w, h);
        else if (n === "gear")
            drawGear(ctx, w, h);
        else if (n === "link")
            drawPlug(ctx, w, h, false);
        else if (n === "unlink")
            drawPlug(ctx, w, h, true);
        else if (n === "lock")
            drawLock(ctx, w, h);
        else if (n === "headphones")
            drawHeadphones(ctx, w, h, "plain");
        else if (n === "headphones-level")
            drawHeadphones(ctx, w, h, "level");
        else if (n === "headphones-mute")
            drawHeadphones(ctx, w, h, "mute");
        else if (n === "close")
            drawClose(ctx, w, h);
        else if (n === "chevron-left")
            drawChevron(ctx, w, h, -1, false);
        else if (n === "chevron-right")
            drawChevron(ctx, w, h, 1, false);
        else if (n === "chevron-double-left")
            drawChevron(ctx, w, h, -1, true);
        else if (n === "chevron-double-right")
            drawChevron(ctx, w, h, 1, true);
        else if (n === "check")
            drawCheck(ctx, w, h);
        else if (n === "radio")
            drawRadio(ctx, w, h, true);
        else if (n === "radio-off")
            drawRadio(ctx, w, h, false);
        else if (n === "keyboard")
            drawKeyboard(ctx, w, h);
        else if (n === "mouse")
            drawMouse(ctx, w, h);
        else if (n === "phone")
            drawPhone(ctx, w, h);
        else if (n === "leaf")
            drawLeaf(ctx, w, h);
        else if (n === "mic")
            drawMic(ctx, w, h, false);
        else if (n === "mic-off")
            drawMic(ctx, w, h, true);
        else if (n === "balance")
            drawBalance(ctx, w, h);
        else if (n === "flash")
            drawFlash(ctx, w, h);
    }

    function drawWifi(ctx, w, h) {
        var cx = w / 2;
        var cy = h * 0.78;
        ctx.lineWidth = Math.max(1.5, h * 0.1);
        ctx.beginPath();
        ctx.arc(cx, cy, Math.max(1, h * 0.09), 0, Math.PI * 2);
        ctx.fill();
        var lv = glyph.level > 0.66 ? 2 : glyph.level > 0.33 ? 1 : 0;
        var radii = [h * 0.28, h * 0.52];
        for (var i = 0; i < lv; i++) {
            ctx.beginPath();
            ctx.arc(cx, cy, radii[i], Math.PI * 1.25, Math.PI * 1.75);
            ctx.stroke();
        }
    }

    function drawEthernet(ctx, w, h) {
        var s = h;
        var ox = (w - s) / 2;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        roundedRect(ctx, ox + 0.16 * s, 0.34 * s, 0.5 * s, 0.32 * s, 0.08 * s);
        ctx.stroke();
        ctx.beginPath();
        for (var i = -1; i <= 1; i++) {
            ctx.moveTo(ox + 0.66 * s, (0.42 + i * 0.08) * s);
            ctx.lineTo(ox + 0.86 * s, (0.42 + i * 0.08) * s);
        }
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(ox + 0.16 * s, 0.5 * s);
        ctx.lineTo(ox + 0.04 * s, 0.5 * s);
        ctx.stroke();
    }

    function drawVolume(ctx, w, h, muted) {
        var s = h;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.09);
        // speaker body
        ctx.beginPath();
        ctx.moveTo(cx - 0.30 * s, 0.38 * s);
        ctx.lineTo(cx - 0.14 * s, 0.38 * s);
        ctx.lineTo(cx + 0.04 * s, 0.20 * s);
        ctx.lineTo(cx + 0.04 * s, 0.80 * s);
        ctx.lineTo(cx - 0.14 * s, 0.62 * s);
        ctx.lineTo(cx - 0.30 * s, 0.62 * s);
        ctx.closePath();
        ctx.fill();
        if (muted) {
            drawMuteCross(ctx, cx + 0.33 * s, 0.50 * s, 0.13 * s, ctx.lineWidth);
            return;
        }
        drawLevelWaves(ctx, cx + 0.04 * s, s, glyph.level, ctx.lineWidth);
    }

    function drawBattery(ctx, w, h) {
        var s = h;
        var bodyW = 0.86 * s;
        var total = bodyW + 0.08 * s;
        var bx = (w - total) / 2;
        var bh = 0.50 * s;
        var by = (h - bh) / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        roundedRect(ctx, bx, by, bodyW, bh, 0.09 * s);
        ctx.stroke();
        // terminal nub, like a AA positive terminal
        roundedRect(ctx, bx + bodyW - 0.05 * s, by + 0.22 * bh, 0.19 * s, 0.56 * bh, 0.03 * s);
        ctx.fill();
        // solid level, filling from the left
        var lvl = Math.max(0, Math.min(1, glyph.level));
        if (lvl > 0) {
            var pad = 0.09 * s;
            roundedRect(ctx, bx + pad, by + pad, Math.max(1, (bodyW - 2 * pad) * lvl), bh - 2 * pad, 0.04 * s);
            ctx.fill();
        }
    }

    function drawPower(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        var cy = h * 0.56;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        ctx.beginPath();
        ctx.arc(cx, cy, 0.30 * s, -Math.PI * 0.24, Math.PI * 1.24);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx, 0.16 * s);
        ctx.lineTo(cx, 0.46 * s);
        ctx.stroke();
    }

    function drawBluetooth(ctx, w, h) {
        // The Bluetooth line logo: upper-left to lower-right, to the bottom,
        // up the stave to the top, out to the upper-right, then to the
        // lower-left. The two left points are the "spikes out the back".
        var pts = [
            [0.0, 0.25],
            [1.0, 0.75],
            [0.5, 1.0],
            [0.5, 0.0],
            [1.0, 0.25],
            [0.0, 0.75]
        ];
        ctx.lineWidth = Math.max(1.5, h * 0.1);
        ctx.beginPath();
        for (var i = 0; i < pts.length; i++) {
            // Keep the drawn height in line with the wifi and media icons.
            var x = (0.25 + pts[i][0] * 0.5) * w;
            var y = (0.2 + pts[i][1] * 0.6) * h;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.stroke();
    }

    function drawBrightness(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        var cy = h / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        ctx.beginPath();
        ctx.arc(cx, cy, 0.20 * s, 0, Math.PI * 2);
        ctx.stroke();
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4;
            ctx.beginPath();
            ctx.moveTo(cx + Math.cos(a) * 0.36 * s, cy + Math.sin(a) * 0.36 * s);
            ctx.lineTo(cx + Math.cos(a) * 0.48 * s, cy + Math.sin(a) * 0.48 * s);
            ctx.stroke();
        }
    }

    function drawPlay(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.lineJoin = "round";
        ctx.lineWidth = Math.max(1.5, s * 0.16);
        ctx.beginPath();
        ctx.moveTo(cx - 0.18 * s, 0.22 * s);
        ctx.lineTo(cx + 0.24 * s, 0.5 * s);
        ctx.lineTo(cx - 0.18 * s, 0.78 * s);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
    }

    function drawPause(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        roundedRect(ctx, cx - 0.24 * s, 0.18 * s, 0.16 * s, 0.64 * s, 0.05 * s);
        ctx.fill();
        roundedRect(ctx, cx + 0.08 * s, 0.18 * s, 0.16 * s, 0.64 * s, 0.05 * s);
        ctx.fill();
    }

    function drawGear(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        var cy = h / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.14);
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4;
            ctx.beginPath();
            ctx.moveTo(cx + Math.cos(a) * 0.26 * s, cy + Math.sin(a) * 0.26 * s);
            ctx.lineTo(cx + Math.cos(a) * 0.44 * s, cy + Math.sin(a) * 0.44 * s);
            ctx.stroke();
        }
        ctx.lineWidth = Math.max(1.5, s * 0.11);
        ctx.beginPath();
        ctx.arc(cx, cy, 0.26 * s, 0, Math.PI * 2);
        ctx.stroke();
    }

    function drawPlug(ctx, w, h, broken) {
        var s = h;
        var cx = w / 2;
        var cy = h / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.11);
        roundedRect(ctx, cx - 0.30 * s, cy - 0.18 * s, 0.40 * s, 0.36 * s, 0.08 * s);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx + 0.10 * s, cy - 0.10 * s);
        ctx.lineTo(cx + 0.30 * s, cy - 0.10 * s);
        ctx.moveTo(cx + 0.10 * s, cy + 0.10 * s);
        ctx.lineTo(cx + 0.30 * s, cy + 0.10 * s);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx - 0.30 * s, cy);
        ctx.lineTo(cx - 0.46 * s, cy);
        ctx.stroke();
        if (broken) {
            ctx.beginPath();
            ctx.moveTo(cx - 0.34 * s, cy - 0.34 * s);
            ctx.lineTo(cx + 0.34 * s, cy + 0.34 * s);
            ctx.stroke();
        }
    }

    function drawLock(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.11);
        ctx.beginPath();
        ctx.arc(cx, 0.40 * s, 0.17 * s, Math.PI, 0);
        ctx.stroke();
        roundedRect(ctx, cx - 0.27 * s, 0.42 * s, 0.54 * s, 0.42 * s, 0.08 * s);
        ctx.stroke();
    }

    function drawHeadphones(ctx, w, h, mode) {
        var s = h;
        // Centre the device plus its side indicator, not just the band.
        var cx = mode === "plain" ? w / 2 : w / 2 - 0.21 * s;
        ctx.lineWidth = Math.max(1.5, s * 0.12);
        // Band: unchanged.
        ctx.beginPath();
        ctx.arc(cx, 0.52 * s, 0.30 * s, Math.PI, 0);
        ctx.stroke();
        // Ear pieces, wider than the band stroke so they read at a glance.
        roundedRect(ctx, cx - 0.36 * s, 0.52 * s, 0.20 * s, 0.26 * s, 0.07 * s);
        ctx.fill();
        roundedRect(ctx, cx + 0.16 * s, 0.52 * s, 0.20 * s, 0.26 * s, 0.07 * s);
        ctx.fill();
        // Level / mute, beside the right ear piece like the speaker's waves.
        if (mode === "mute")
            drawMuteCross(ctx, cx + 0.58 * s, 0.50 * s, 0.13 * s, Math.max(1.5, s * 0.09));
        else if (mode === "level")
            drawLevelWaves(ctx, cx + 0.36 * s, s, glyph.level, Math.max(1.5, s * 0.09));
    }

    function drawClose(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        var cy = h / 2;
        var r = 0.28 * s;
        ctx.lineWidth = Math.max(1.5, s * 0.12);
        ctx.beginPath();
        ctx.moveTo(cx - r, cy - r);
        ctx.lineTo(cx + r, cy + r);
        ctx.moveTo(cx + r, cy - r);
        ctx.lineTo(cx - r, cy + r);
        ctx.stroke();
    }

    // `dir` is 1 for a chevron pointing right, -1 for left; `pair` draws two.
    // Each V is centred on its own midpoint so single and double read evenly.
    function drawChevron(ctx, w, h, dir, pair) {
        var s = h;
        var cx = w / 2;
        var cy = h / 2;
        var reach = 0.20 * s;
        var half = 0.24 * s;
        ctx.lineWidth = Math.max(1.5, s * 0.12);
        var centers = pair ? [-0.17 * s, 0.17 * s] : [0];
        for (var i = 0; i < centers.length; i++) {
            var mid = cx + centers[i];
            var tip = mid + dir * reach / 2;
            var back = mid - dir * reach / 2;
            ctx.beginPath();
            ctx.moveTo(back, cy - half);
            ctx.lineTo(tip, cy);
            ctx.lineTo(back, cy + half);
            ctx.stroke();
        }
    }

    function drawCheck(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.13);
        ctx.beginPath();
        ctx.moveTo(cx - 0.26 * s, 0.52 * s);
        ctx.lineTo(cx - 0.06 * s, 0.72 * s);
        ctx.lineTo(cx + 0.28 * s, 0.28 * s);
        ctx.stroke();
    }

    function drawRadio(ctx, w, h, filled) {
        var s = h;
        var cx = w / 2;
        var cy = h / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.11);
        ctx.beginPath();
        ctx.arc(cx, cy, 0.30 * s, 0, Math.PI * 2);
        if (filled)
            ctx.fill();
        else
            ctx.stroke();
    }

    function drawKeyboard(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.09);
        roundedRect(ctx, cx - 0.36 * s, 0.32 * s, 0.72 * s, 0.36 * s, 0.06 * s);
        ctx.stroke();
        ctx.beginPath();
        for (var i = 0; i < 3; i++) {
            ctx.moveTo(cx - 0.24 * s + i * 0.16 * s, 0.58 * s);
            ctx.lineTo(cx - 0.16 * s + i * 0.16 * s, 0.58 * s);
        }
        ctx.stroke();
    }

    function drawMouse(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        roundedRect(ctx, cx - 0.20 * s, 0.18 * s, 0.40 * s, 0.64 * s, 0.18 * s);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx, 0.30 * s);
        ctx.lineTo(cx, 0.46 * s);
        ctx.stroke();
    }

    function drawPhone(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        roundedRect(ctx, cx - 0.18 * s, 0.14 * s, 0.36 * s, 0.72 * s, 0.08 * s);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx - 0.07 * s, 0.76 * s);
        ctx.lineTo(cx + 0.07 * s, 0.76 * s);
        ctx.stroke();
    }

    function drawMic(ctx, w, h, off) {
        var s = h;
        // Centre the mic plus its side indicator, not just the capsule.
        var cx = w / 2 - 0.21 * s;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        roundedRect(ctx, cx - 0.13 * s, 0.16 * s, 0.26 * s, 0.40 * s, 0.13 * s);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(cx, 0.50 * s, 0.24 * s, 0.12 * Math.PI, 0.88 * Math.PI);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx, 0.74 * s);
        ctx.lineTo(cx, 0.86 * s);
        ctx.moveTo(cx - 0.10 * s, 0.86 * s);
        ctx.lineTo(cx + 0.10 * s, 0.86 * s);
        ctx.stroke();
        if (off)
            drawMuteCross(ctx, cx + 0.45 * s, 0.50 * s, 0.13 * s, Math.max(1.5, s * 0.09));
        else
            drawLevelWaves(ctx, cx + 0.24 * s, s, glyph.level, Math.max(1.5, s * 0.09));
    }

    function drawLeaf(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        ctx.beginPath();
        ctx.moveTo(cx - 0.30 * s, 0.74 * s);
        ctx.quadraticCurveTo(cx - 0.34 * s, 0.22 * s, cx + 0.30 * s, 0.18 * s);
        ctx.quadraticCurveTo(cx + 0.18 * s, 0.62 * s, cx - 0.30 * s, 0.74 * s);
        ctx.closePath();
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx - 0.26 * s, 0.70 * s);
        ctx.lineTo(cx + 0.14 * s, 0.34 * s);
        ctx.stroke();
    }

    function drawBalance(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.lineWidth = Math.max(1.5, s * 0.1);
        ctx.beginPath();
        ctx.moveTo(cx - 0.40 * s, 0.30 * s);
        ctx.lineTo(cx + 0.40 * s, 0.30 * s);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx, 0.18 * s);
        ctx.lineTo(cx, 0.80 * s);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(cx - 0.28 * s, 0.30 * s, 0.12 * s, 0, Math.PI);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(cx + 0.28 * s, 0.30 * s, 0.12 * s, 0, Math.PI);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx - 0.16 * s, 0.80 * s);
        ctx.lineTo(cx + 0.16 * s, 0.80 * s);
        ctx.stroke();
    }

    function drawFlash(ctx, w, h) {
        var s = h;
        var cx = w / 2;
        ctx.beginPath();
        ctx.moveTo(cx + 0.18 * s, 0.12 * s);
        ctx.lineTo(cx - 0.34 * s, 0.54 * s);
        ctx.lineTo(cx - 0.06 * s, 0.54 * s);
        ctx.lineTo(cx - 0.18 * s, 0.88 * s);
        ctx.lineTo(cx + 0.34 * s, 0.46 * s);
        ctx.lineTo(cx + 0.06 * s, 0.46 * s);
        ctx.closePath();
        ctx.fill();
    }
}
