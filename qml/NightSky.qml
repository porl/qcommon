import QtQuick
import "NightSkySim.js" as Sim

// A night skyline: buildings on a handful of depth bands, a fixed starfield that
// twinkles, a moon on its own slow arc, and occasional meteors. Each band is its
// own Canvas, slightly wider than the screen, that is *translated* to pan — so
// motion is smooth without repainting every frame. Whatever moves in the sky
// (meteors, interceptors, explosions) shares one canvas that only repaints while
// something is on it. One clock drives the pan, the sky and the movers, so a tick
// is one composite. The view only; a wrapper owns the layer-shell surface.
Item {
    id: root

    clip: true

    property var theme
    property int seed: 1
    property bool running: true

    // Pan in logical px/s for the nearest band; further bands are slower.
    property real panSpeed: 1
    // Parallax: near bands move at `panNear`× and far bands at `panFar`× of
    // `panSpeed`. A wide ratio is what makes the depth read.
    property real panNear: 1.8
    property real panFar: 0.15
    // One clock for everything that moves: the band pan, the sky and the movers.
    // Every tick causes exactly one composite, so a single rate is also the whole
    // frame budget.
    property int fps: 6
    // Motion speeds below are stated for a 10fps clock and scaled with the actual
    // rate, so every mover covers the same px per frame at any frame rate.
    readonly property real motionScale: fps / 10
    // Meteors: on/off, base rate (per second), and optional "showers" — a spell
    // of more frequent meteors sharing one direction, not a burst.
    property bool meteorsEnabled: true
    // Buildings can be switched off for a plain starfield (cheaper: no band
    // canvases to composite, no pan).
    property bool buildingsEnabled: true
    property real meteorRate: 0.08 // expected meteors per second
    property bool meteorShowers: true
    property real showerRate: 0.008 // chance per second to begin a shower
    property real showerDuration: 15 // seconds
    property real showerMultiplier: 5

    // Missile command: the city fires red-tailed interceptors at every meteor.
    // Meteors no longer burn out — they are only gone when hit or when they reach
    // the buildings, and either ends in a small explosion. This is the expensive
    // mode: while anything is in the sky the motion canvas repaints every tick.
    // Meteors arrive about twice as often so the city has something to do.
    property bool missileCommand: false
    // Turrets can be switched off (they stay masts) — useful to watch meteors
    // actually reach the buildings.
    property bool turretsEnabled: true
    // Missile command keeps the sky as busy as a shower, but every meteor still
    // picks its own heading (showers, and their shared heading, are a normal-mode
    // thing). 5 matches `showerMultiplier`, so the pace feels the same.
    property real missileMeteorRateScale: 5
    // Speeds are absolute px/s, deliberately not scaled by screen size.
    property real meteorSpeedMin: 10
    property real meteorSpeedMax: 26
    property real missileSpeed: 80
    property real explosionSpeed: 45
    // Halfway between the old 10fps value (120) and its fps-corrected 6fps value
    // (72): the fully-corrected fall felt too floaty/pre-rounded, the unchanged
    // one too heavy (ejecta never rose).
    property real explosionGravity: 96
    property real interceptDelay: 0.6 // seconds before the city responds
    property real missileHitRadius: 8
    property real missileTailSeconds: 0.3
    property real explosionLife: 0.7
    property int explosionParticles: 14 // maximum; the count is random 0..this
    // Turret aiming: turn at most this many rad/s (never snapping), and only fire
    // once the barrel is within `fireTolerance` of the target bearing. The band is
    // repainted only when the barrel tip would move at least `turretRepaintPx`.
    property real turretSlew: 4
    property real fireTolerance: 0.15
    property real turretRepaintPx: 1

    // Antialiasing: stars and streaks are drawn as small sub-pixel circles instead
    // of snapped pixel blocks, so they drift smoothly rather than hopping between
    // pixels. Costs a little more to paint; switch off if it spikes CPU.
    property bool antialias: true

    property int cellW: 5
    property int cellH: 9

    // The world advances a few cells at a time; a lagging repaint can then only
    // move a band a few px.
    readonly property int panStepCells: 4
    readonly property int panSpan: panStepCells * cellW

    property var _skyline: null
    property var _facade: []
    property var _on: []
    property var _off: []
    property var _star: []
    property var _starXY: [] // precomputed star positions; the field does not rotate
    property var _missileCols: []
    property var _flash: []
    property color _moon: "#000000"
    property var _turrets: [] // fixed firing positions, built from the skyline
    property var _turretAim: []
    property var _turretFor: ({}) // band+bid -> turret index

    property real _time: 0
    property real _mt: 0
    property var _pan: [] // px per band, mutated in place
    property var _wOff: [] // world offset in cells per band
    property var _nodes: [] // Canvas items by band
    property var _flips: ({}) // per-window light overrides
    property var _meteors: []
    property var _missiles: []
    property var _explosions: []
    property real _showerUntil: 0
    property real _showerDir: 0

    function _hexToRgb(hex) {
        var h = ("" + hex);
        if (h.charAt(0) === "#")
            h = h.substring(1);
        if (h.length === 8)
            h = h.substring(2);
        if (h.length === 3)
            h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
        return [parseInt(h.substring(0, 2), 16), parseInt(h.substring(2, 4), 16), parseInt(h.substring(4, 6), 16)];
    }

    function _mix(a, b, t) {
        var ca = _hexToRgb(a);
        var cb = _hexToRgb(b);
        return "rgb(" + Math.round(ca[0] + (cb[0] - ca[0]) * t) + "," + Math.round(ca[1] + (cb[1] - ca[1]) * t) + "," + Math.round(ca[2] + (cb[2] - ca[2]) * t) + ")";
    }

    function _ramp(from, to, steps) {
        var out = [];
        for (var i = 0; i < steps; ++i) {
            var d = steps > 1 ? i / (steps - 1) : 1;
            out.push(_mix(from, to, d));
        }
        return out;
    }

    // One point of light. Antialiased mode draws a small circle at the fractional
    // position, so sub-pixel motion reads as smooth drift; otherwise it is a
    // snapped pixel block. (A fractional rect is *not* antialiased here — it snaps
    // outward to a hard block — so the path is what buys the smoothness.)
    function _dot(ctx, x, y, size) {
        if (antialias) {
            ctx.beginPath();
            ctx.arc(x, y, size * 0.5, 0, Math.PI * 2);
            ctx.fill();
        } else {
            ctx.fillRect(Math.floor(x), Math.floor(y), size, size);
        }
    }

    function _buildColours() {
        var t = theme;
        var facade = [];
        var on = [];
        var off = [];
        for (var l = 0; l < Sim.LEVELS; ++l) {
            var d = Sim.LEVELS > 1 ? l / (Sim.LEVELS - 1) : 1;
            facade[l] = _mix(t.skyTop, t.buildingGlow, 0.01 + 0.02 * d);
            off[l] = _mix(t.skyTop, t.buildingGlow, 0.10 + 0.12 * d);
            on[l] = _mix(t.skyTop, t.buildingGlow, 0.35 + 0.65 * d);
        }
        _facade = facade;
        _on = on;
        _off = off;
        _star = _ramp(t.skyTop, t.starGlow, Sim.STAR_LEVELS);
        _missileCols = _ramp(t.skyTop, t.missileTrail, Sim.STAR_LEVELS);
        _flash = _ramp(t.skyTop, t.explosionGlow, Sim.STAR_LEVELS);
        _moon = t.moonGlow;
    }

    onThemeChanged: _rebuild()

    function _rebuild() {
        if (!theme)
            return;
        _buildColours();
        _skyline = Sim.makeSkyline(seed);
        _buildTurrets();
        // Star positions are fixed (the field no longer rotates), so resolve them
        // once instead of doing trig for every star every frame.
        var cx = width * 0.5;
        var cy = height * 1.6;
        var R = Math.sqrt(width * width + height * height) * 1.2;
        var pts = [];
        var src = _skyline.stars;
        for (var s = 0; s < src.length; ++s) {
            var st = src[s];
            var r = st[0] * R;
            pts.push([cx + r * Math.cos(st[1]), cy + r * Math.sin(st[1]), st[2], st[3]]);
        }
        _starXY = pts;
        var pans = [];
        var offs = [];
        for (var i = 0; i < Sim.N_DEPTHS; ++i) {
            pans.push(0);
            offs.push(0);
        }
        _pan = pans;
        _wOff = offs;
        _flips = ({});
        _meteors = [];
        _missiles = [];
        _explosions = [];
        _showerUntil = 0;
        _time = 0;
        _mt = 0;
        for (var b = 0; b < Sim.N_DEPTHS; ++b) {
            if (_nodes[b]) {
                _nodes[b].panVal = 0;
                _nodes[b].requestPaint();
            }
        }
        skyCanvas.requestPaint();
        motionCanvas.requestPaint();
    }

    onSeedChanged: _rebuild()
    onWidthChanged: _rebuild()
    onMissileCommandChanged: {
        _missiles = [];
        _explosions = [];
        for (var tb = 0; tb < _turrets.length; ++tb) {
            _turrets[tb].target = null;
            _turrets[tb].pending = false;
        }
        for (var nb2 = 0; nb2 < Sim.N_DEPTHS; ++nb2) {
            if (_nodes[nb2])
                _nodes[nb2].requestPaint();
        }
        motionCanvas.requestPaint();
    }
    onBuildingsEnabledChanged: {
        for (var nb = 0; nb < Sim.N_DEPTHS; ++nb) {
            if (_nodes[nb])
                _nodes[nb].requestPaint();
        }
    }
    onTurretsEnabledChanged: {
        for (var nm = 0; nm < Sim.N_DEPTHS; ++nm) {
            if (_nodes[nm])
                _nodes[nm].requestPaint();
        }
    }

    function _panStep(dt) {
        if (!_skyline || !buildingsEnabled)
            return;
        for (var db = 0; db < Sim.N_DEPTHS; ++db) {
            _pan[db] += panSpeed * Sim.panFactor(1 - Sim.bandDist(db), panNear, panFar) * dt;
            if (_pan[db] >= panSpan) {
                _pan[db] -= panSpan;
                _wOff[db] += panStepCells;
                // The world is periodic; keep the offset inside it or the city
                // scrolls off and never comes back.
                if (_wOff[db] >= Sim.WORLD_W)
                    _wOff[db] -= Sim.WORLD_W;
                if (_nodes[db])
                    _nodes[db].requestPaint();
            }
            // The delegate's x is bound to panVal; assigning it is what actually
            // moves the band. (Mutating the array alone would not notify QML.)
            if (_nodes[db])
                _nodes[db].panVal = _pan[db];
        }
    }

    // The surface a meteor meets at screen x: the top of the tallest building
    // covering that x, or the bottom of the screen where the silhouette is open —
    // so a meteor that misses every building falls the full height instead of
    // exploding in mid-air. The geometry itself lives in the sim so it can be
    // tested; the band's continuous pan is part of the offset.
    function _surfaceAt(x) {
        if (!_skyline || !buildingsEnabled)
            return height;
        var offsets = [];
        for (var db = 0; db < Sim.N_DEPTHS; ++db)
            offsets.push(_wOff[db] + _pan[db] / cellW);
        var maxH = Sim.buildingHeightAt(_skyline, x, offsets, cellW, Sim.WORLD_W);
        return height - maxH * height;
    }

    function _spawnMeteor() {
        // Downward-ish: 63-117 degrees, so nothing travels upward. During a
        // shower they all share a direction.
        var dir = _mt < _showerUntil ? _showerDir : Sim.meteorDirection(Math.random);
        var speed = (meteorSpeedMin + Math.random() * (meteorSpeedMax - meteorSpeedMin)) * motionScale;
        _meteors.push({
            x: Math.random() * width,
            y: Math.random() * height * 0.6,
            vx: Math.cos(dir) * speed,
            vy: Math.sin(dir) * speed,
            t0: _mt,
            life: 2 + Math.random() * 1.5,
            mag: 0.4 + Math.random() * 0.35
        });
    }

    // Firing positions are fixed to the skyline: every building that carries a
    // mast gets a turret. They are stored in world cells (so they pan with their
    // band) and mapped to screen positions on demand.
    function _buildTurrets() {
        var list = [];
        var index = ({});
        if (_skyline) {
            for (var db = 0; db < Sim.N_DEPTHS; ++db) {
                var buildings = _skyline.layers[db];
                for (var i = 0; i < buildings.length; ++i) {
                    var bd = buildings[i];
                    if (bd.antenna) {
                        index[db * 100003 + bd.bid] = list.length;
                        list.push({
                            band: db,
                            bid: bd.bid,
                            xCells: bd.x + bd.w / 2,
                            hFrac: bd.h,
                            target: null,
                            pending: false
                        });
                    }
                }
            }
        }
        _turrets = list;
        _turretFor = index;
        var aims = [];
        for (var a = 0; a < list.length; ++a)
            aims.push(-Math.PI / 2);
        _turretAim = aims;
    }

    // A turret's on-screen position, choosing the periodic tile nearest the
    // screen centre (the world is wider than the screen). Includes the band's
    // continuous pan, so it stays glued to its building.
    function _turretScreen(tr) {
        var cw = cellW;
        var worldPx = Sim.WORLD_W * cw;
        var g = tr.band;
        var base = tr.xCells * cw - _wOff[g] * cw - _pan[g];
        var k = Math.round((width / 2 - base) / worldPx);
        return {
            x: base + k * worldPx,
            y: height - tr.hFrac * height
        };
    }

    // Barrel length for a turret, matched by the drawing and the firing origin so
    // the missile leaves the tip.
    function _turretBar(tr) {
        return 3 + (1 - Sim.bandDist(tr.band)) * 4;
    }

    // Aim each turret at its target, turning at a limited rate (never snapping and
    // never pointing down). The tracking barrel is drawn on the band canvas, so a
    // changing aim means repainting that band; missile mode is the expensive mode
    // and this is why.
    function _updateTurrets(dt) {
        if (!turretsEnabled)
            return;
        var maxStep = turretSlew * motionScale * dt;
        for (var i = 0; i < _turrets.length; ++i) {
            var tr = _turrets[i];
            var want = -Math.PI / 2;
            if (tr.target && _meteors.indexOf(tr.target) >= 0) {
                var pos = _turretScreen(tr);
                want = Math.atan2(tr.target.y - pos.y, tr.target.x - pos.x);
            } else {
                tr.target = null;
                tr.pending = false;
            }
            var aim = Sim.slewAim(_turretAim[i], want, maxStep, -Math.PI, 0);
            // Repaint only when the barrel tip would actually move: barrels are
            // only a few px long, so sub-pixel aim changes are not worth a band
            // repaint. Tracking therefore repaints in ~px steps, not every tick.
            if (Math.abs(aim - _turretAim[i]) * _turretBar(tr) >= turretRepaintPx) {
                _turretAim[i] = aim;
                if (_nodes[tr.band])
                    _nodes[tr.band].requestPaint();
            }
        }
    }

    function _maybeIntercept() {
        if (!missileCommand || !turretsEnabled)
            return;
        for (var i = 0; i < _meteors.length; ++i) {
            var m = _meteors[i];
            if (_mt - m.t0 < interceptDelay)
                continue;
            var hasMissile = false;
            for (var j = 0; j < _missiles.length; ++j) {
                if (_missiles[j].target === m) {
                    hasMissile = true;
                    break;
                }
            }
            if (hasMissile)
                continue;
            // A turret already swinging onto this meteor keeps it; otherwise pick
            // the nearest turret that is not mid-shot. A turret is free again the
            // moment it fires, so it need not wait for the missile to land.
            var assigned = -1;
            for (var a = 0; a < _turrets.length; ++a) {
                if (_turrets[a].pending && _turrets[a].target === m) {
                    assigned = a;
                    break;
                }
            }
            if (assigned < 0) {
                var best = -1;
                var bestD = Infinity;
                for (var ti = 0; ti < _turrets.length; ++ti) {
                    var tr = _turrets[ti];
                    if (tr.pending)
                        continue;
                    var pos = _turretScreen(tr);
                    if (pos.x < -10 || pos.x > width + 10)
                        continue;
                    var dx = pos.x - m.x;
                    var dy = pos.y - m.y;
                    var d = dx * dx + dy * dy;
                    if (d < bestD) {
                        bestD = d;
                        best = ti;
                    }
                }
                if (best < 0)
                    continue;
                _turrets[best].target = m;
                _turrets[best].pending = true;
                assigned = best;
            }
            var turret = _turrets[assigned];
            var tpos = _turretScreen(turret);
            var bearing = Math.atan2(m.y - tpos.y, m.x - tpos.x);
            // Fire only once the barrel has swung on target.
            if (Math.abs(Sim.angleDiff(_turretAim[assigned], bearing)) > fireTolerance)
                continue;
            turret.pending = false;
            var bar = _turretBar(turret);
            var tipX = tpos.x + Math.cos(bearing) * bar;
            var tipY = tpos.y + Math.sin(bearing) * bar;
            var mspeed = missileSpeed * motionScale;
            _missiles.push({
                x: tipX,
                y: tipY,
                x0: tipX,
                y0: tipY,
                vx: Math.cos(bearing) * mspeed,
                vy: Math.sin(bearing) * mspeed,
                speed: mspeed,
                target: m
            });
        }
    }

    function _explode(x, y) {
        _explosions.push(Sim.makeExplosion(x, y, explosionParticles, Math.random, explosionSpeed, _mt, explosionGravity));
    }

    // Advance the moving sky by dt. Positions are integrated (missiles steer, so
    // they cannot be solved from a start time); collisions use a segment test so a
    // fast interceptor cannot tunnel through a slow meteor between frames.
    function _stepSky(dt) {
        if (!_skyline)
            return;

        for (var mi = _meteors.length - 1; mi >= 0; --mi) {
            var m = _meteors[mi];
            m.x += m.vx * dt;
            m.y += m.vy * dt;
            if (missileCommand) {
                if (m.y >= _surfaceAt(m.x)) {
                    // Reached a building (or the bottom of an open gap).
                    _explode(m.x, Math.max(0, m.y - 2));
                    _meteors.splice(mi, 1);
                }
            } else if (_mt - m.t0 > m.life) {
                _meteors.splice(mi, 1);
            }
        }

        for (var si = _missiles.length - 1; si >= 0; --si) {
            var s = _missiles[si];
            var tgt = s.target;
            if (!tgt || _meteors.indexOf(tgt) < 0) {
                _missiles.splice(si, 1);
                continue;
            }
            var ox = s.x;
            var oy = s.y;
            var ang = Math.atan2(tgt.y - s.y, tgt.x - s.x);
            s.vx = Math.cos(ang) * s.speed;
            s.vy = Math.sin(ang) * s.speed;
            s.x += s.vx * dt;
            s.y += s.vy * dt;
            if (Sim.segmentDistance(ox, oy, s.x, s.y, tgt.x, tgt.y) <= missileHitRadius) {
                _explode((s.x + tgt.x) / 2, (s.y + tgt.y) / 2);
                var hitAt = _meteors.indexOf(tgt);
                if (hitAt >= 0)
                    _meteors.splice(hitAt, 1);
                _missiles.splice(si, 1);
            }
        }

        for (var ei = _explosions.length - 1; ei >= 0; --ei) {
            if (Sim.explosionExpired(_explosions[ei], _mt, explosionLife))
                _explosions.splice(ei, 1);
        }

        _updateTurrets(dt);
        _maybeIntercept();
    }

    function _skyBusy() {
        return _meteors.length > 0 || _missiles.length > 0 || _explosions.length > 0;
    }

    function _drawBand(ctx, band, offset, canvasW, canvasH) {
        var buildings = _skyline.layers[band];
        var nearness = 1 - Sim.bandDist(band);
        var lvlBase = Math.round(nearness * (Sim.LEVELS - 1));
        var cw = cellW;
        var ch = cellH;
        var worldPx = Sim.WORLD_W * cw;
        for (var bi = 0; bi < buildings.length; ++bi) {
            var bd = buildings[bi];
            var bw = bd.w * cw;
            var bx = bd.x * cw - offset * cw;
            // Window size is a fraction of the floor cell, driven by the building's
            // own height (tallest get the largest), with variance for small ones.
            var dw = Math.max(1, Math.round((cw - 1) * bd.win));
            var dh = Math.max(1, Math.round((ch - 3) * bd.win));
            // Tile so a wrapped offset never shows a gap.
            for (var t = -1; t <= 1; ++t) {
                var x0 = bx + t * worldPx;
                if (x0 + bw < 0 || x0 > canvasW)
                    continue;
                var top = Math.floor(canvasH - bd.h * root.height);
                var rowsN = Math.max(1, Math.floor((canvasH - top) / ch));

                ctx.fillStyle = _facade[lvlBase];
                ctx.fillRect(x0, top, bw, canvasH - top);

                for (var gx = 0; gx < bd.w; ++gx) {
                    var wx = x0 + gx * cw;
                    if (wx + cw < 0 || wx > canvasW)
                        continue;
                    var rel = bd.w > 1 ? gx / (bd.w - 1) : 0;
                    var lvl = Sim.clamp(lvlBase + Math.round(2 * Math.cos(rel * Math.PI)), 0, Sim.LEVELS - 1);
                    var colOn = _on[lvl];
                    var colOff = _off[lvl];
                    for (var gy = 0; gy < rowsN; ++gy) {
                        var wy = top + gy * ch;
                        ctx.fillStyle = Sim.windowOn(bd.bid, gx, gy, bd.lit, _flips) ? colOn : colOff;
                        ctx.fillRect(wx + Math.floor((cw - dw) / 2), wy + Math.floor((ch - dh) / 2), dw, dh);
                    }
                }

                if (bd.antenna) {
                    if (root.missileCommand && root.turretsEnabled) {
                        var tix = root._turretFor[band * 100003 + bd.bid];
                        root._drawTurret(ctx, x0 + bw / 2, top, nearness, root._turretAim[tix]);
                    } else {
                        ctx.fillStyle = _on[lvlBase];
                        ctx.fillRect(x0 + Math.floor(bw / 2), top - 8, 2, 8);
                    }
                }
            }
        }
    }

    // A turret: a small dome sitting on the roof with an aiming barrel. Drawn as
    // part of the band, so it pans with its building and is occluded correctly.
    function _drawTurret(ctx, cx, baseY, nearness, aim) {
        var rad = 1.5 + nearness * 2.5;
        var bar = 3 + nearness * 4;
        var lvl = Math.round(nearness * (Sim.LEVELS - 1));
        ctx.fillStyle = _on[lvl];
        ctx.beginPath();
        ctx.arc(cx, baseY, rad, Math.PI, 2 * Math.PI);
        ctx.fill();
        ctx.strokeStyle = _on[lvl];
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(cx, baseY);
        ctx.lineTo(cx + Math.cos(aim) * bar, baseY + Math.sin(aim) * bar);
        ctx.stroke();
    }

    // A head with a tail behind it, drawn from a colour ramp. `bright` scales the
    // whole streak; `tailMax` is seconds of travel behind the head, optionally
    // capped in px (`tailCapPx`) so a missile's tail grows out of the muzzle
    // instead of being drawn back over the turret it was fired from.
    function _drawStreak(ctx, x, y, vx, vy, tailMax, bright, cols, tailCapPx) {
        var speed = Math.sqrt(vx * vx + vy * vy);
        if (speed <= 0)
            return;
        var ux = vx / speed;
        var uy = vy / speed;
        var tailPx = speed * tailMax;
        if (tailCapPx !== undefined)
            tailPx = Math.min(tailPx, tailCapPx);
        var steps = Math.max(8, Math.floor(tailPx));
        for (var k = 1; k < steps; ++k) {
            var f = k / steps;
            var px = x - ux * f * tailPx;
            var py = y - uy * f * tailPx;
            if (px < 0 || px > width || py < 0 || py > height)
                continue;
            var fade = (1 - f) * bright;
            var lvl = Math.floor(Sim.clamp(fade, 0, 1) * (Sim.STAR_LEVELS - 1));
            ctx.fillStyle = cols[lvl];
            _dot(ctx, px, py, 1);
        }
        if (x >= -2 && x <= width + 2 && y >= -2 && y <= height + 2) {
            ctx.fillStyle = cols[Math.floor(Sim.clamp(bright, 0, 1) * (Sim.STAR_LEVELS - 1))];
            _dot(ctx, x, y, 2);
        }
    }

    // The sky is a scene-graph gradient, not a Canvas fill.
    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.theme ? root.theme.skyTop : "#04040a"
            }
            GradientStop {
                position: 1.0
                color: root.theme ? root.theme.skyBottom : "#12122a"
            }
        }
    }

    // Starfield and moon: slow, so this repaints rarely.
    Canvas {
        id: skyCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var skyline = root._skyline;
            if (!skyline)
                return;

            // Stars: fixed positions (no rotation), only the twinkle changes, so
            // this is a walk over precomputed points rather than per-frame trig.
            var stars = root._starXY;
            for (var s = 0; s < stars.length; ++s) {
                var st = stars[s];
                if (st[0] < -2 || st[0] > width + 2 || st[1] < -2 || st[1] > height + 2)
                    continue;
                var b = 0.3 + 0.6 * st[2] + 0.15 * Math.sin(root._time * 0.12 + st[3]);
                var si = Math.floor(Math.max(0, Math.min(1, b)) * (Sim.STAR_LEVELS - 1));
                ctx.fillStyle = root._star[si];
                root._dot(ctx, st[0], st[1], 2);
            }

            // Moon: its own slow east-to-west arc.
            var moonPhase = (root._time / 2400) % 1; // ~40 min across the sky
            var mx = (-0.1 + 1.2 * moonPhase) * width;
            var my = (0.30 - 0.20 * Math.sin(Math.PI * moonPhase)) * height;
            var mr = Math.max(5, Math.min(width, height) * 0.017);
            ctx.fillStyle = root._moon;
            ctx.beginPath();
            ctx.arc(mx, my, mr, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = root._mix(root.theme.skyTop, root.theme.skyBottom, my / height);
            ctx.beginPath();
            ctx.arc(mx + mr * 0.9, my - mr * 0.2, mr * 0.98, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // Far bands first (declared first, so nearer bands paint over them).
    Repeater {
        model: Sim.N_DEPTHS

        delegate: Canvas {
            required property int index

            readonly property int band: Sim.N_DEPTHS - 1 - index
            readonly property int bandH: Math.ceil(Sim.bandMaxHeight(band) * root.height) + 8

            property real panVal: 0

            x: -panVal
            y: root.height - bandH
            height: bandH
            width: root.width + root.panSpan
            visible: root.buildingsEnabled

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (root._skyline)
                    root._drawBand(ctx, band, root._wOff[band], width, height);
            }

            Component.onCompleted: root._nodes[band] = this
            Component.onDestruction: root._nodes[band] = null
        }
    }

    // Meteors, interceptors and explosions: the only fast-moving things. This
    // canvas repaints only while something is in the sky.
    Canvas {
        id: motionCanvas

        x: 0
        y: 0
        width: root.width
        height: root.height

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var meteors = root._meteors;
            for (var mi = 0; mi < meteors.length; ++mi) {
                var m = meteors[mi];
                // Burn out: hold brightness, then fade smoothly to nothing so a
                // meteor that dies on screen does not just vanish. In missile
                // command nothing burns out — it is shot down or hits the city.
                var bright = 1;
                if (!root.missileCommand) {
                    var age = root._mt - m.t0;
                    bright = age < m.life * 0.5 ? 1 : Math.max(0, 1 - (age - m.life * 0.5) / (m.life * 0.5));
                }
                root._drawStreak(ctx, m.x, m.y, m.vx, m.vy, 2, bright * m.mag, root._star);
            }

            var missiles = root._missiles;
            for (var si = 0; si < missiles.length; ++si) {
                var s = missiles[si];
                // Tail length is capped by distance travelled, so it grows out of
                // the muzzle rather than being drawn back over the turret.
                var travelled = Math.sqrt((s.x - s.x0) * (s.x - s.x0) + (s.y - s.y0) * (s.y - s.y0));
                root._drawStreak(ctx, s.x, s.y, s.vx, s.vy, root.missileTailSeconds, 0.9, root._missileCols, travelled);
            }

            var explosions = root._explosions;
            for (var ei = 0; ei < explosions.length; ++ei) {
                var e = explosions[ei];
                if (Sim.explosionExpired(e, root._mt, root.explosionLife))
                    continue;
                var age = root._mt - e.t0;
                var fade = Math.max(0, 1 - age / root.explosionLife);
                var lvl = Math.floor(Sim.clamp(fade, 0, 1) * (Sim.STAR_LEVELS - 1));
                // A brief central flash, gone in the first half, while the ring
                // expands outward and fades as it grows.
                if (fade > 0.5) {
                    ctx.fillStyle = root._flash[lvl];
                    root._dot(ctx, e.x, e.y, 3);
                }
                for (var pi = 0; pi < e.parts.length; ++pi) {
                    var pos = Sim.particleAt(e, e.parts[pi], age);
                    var ex = pos[0];
                    var ey = pos[1];
                    if (ex < 0 || ex > width || ey < 0 || ey > height)
                        continue;
                    var el = Math.floor(Sim.clamp(fade * 0.8, 0, 1) * (Sim.STAR_LEVELS - 1));
                    ctx.fillStyle = root._flash[el];
                    root._dot(ctx, ex, ey, 1);
                }
            }
        }
    }

    // One clock drives the pan, the starfield and the sky movers, so a tick is
    // exactly one composite.
    Timer {
        interval: root.fps > 0 ? Math.round(1000 / root.fps) : 1000
        running: root.running
        repeat: true
        onTriggered: {
            var dt = interval / 1000;
            root._panStep(dt);
            root._time += dt;
            skyCanvas.requestPaint();
            var wasBusy = root._skyBusy();
            root._mt += dt;
            root._stepSky(dt);
            // Repaint while anything is in the sky, and once more when the last
            // one goes: without that final paint its last frame stays frozen on
            // the canvas (which is how spent explosions used to linger).
            if (wasBusy || root._skyBusy())
                motionCanvas.requestPaint();
        }
    }

    // A couple of windows change each second; only the affected bands repaint.
    Timer {
        interval: 1000
        running: root.running
        repeat: true
        onTriggered: {
            if (!root._skyline || !root.buildingsEnabled)
                return;
            for (var i = 0; i < 2; ++i) {
                var db = Sim.toggleRandom(root._skyline, root._flips, Math.random, root.height, root.cellH);
                if (root._nodes[db])
                    root._nodes[db].requestPaint();
            }
        }
    }

    // Meteor spawning.
    Timer {
        interval: 1000
        running: root.running
        repeat: true
        onTriggered: {
            if (!root.meteorsEnabled)
                return;
            var rate = root.meteorRate;
            if (root.missileCommand) {
                // Missile command is always as busy as a shower, but each meteor
                // still picks its own heading.
                rate *= root.missileMeteorRateScale;
            } else if (root.meteorShowers) {
                if (root._mt < root._showerUntil) {
                    rate *= root.showerMultiplier;
                } else if (Math.random() < root.showerRate) {
                    root._showerUntil = root._mt + root.showerDuration;
                    root._showerDir = Sim.meteorDirection(Math.random);
                }
            }
            if (Math.random() < rate)
                root._spawnMeteor();
        }
    }

    Component.onCompleted: _rebuild()
}
