.pragma library

// Night sky — the simulation, with no QML types in it.
//
// A night skyline in the After Dark "Starry Night" idiom. Buildings live on a
// dozen depth bands: nearer bands are taller, brighter, use larger windows, and
// pan faster, which is where both the depth and the motion come from. Windows are
// on or off and change slowly. Data and pure functions only.

var LEVELS = 6; // brightness steps across the depth range
var STAR_LEVELS = 24; // star brightness steps, many so the twinkle fades smoothly

var N_DEPTHS = 5; // 0 = nearest
var WORLD_W = 1400; // cells of scroll room per band

// Building height runs from HEIGHT_MIN at the ends of the depth range up to
// HEIGHT_MIN + HEIGHT_RANGE at the middle-peak.
var HEIGHT_MIN = 0.10;
var HEIGHT_RANGE = 0.24;
var MAX_BUILDING_HEIGHT = HEIGHT_MIN + HEIGHT_RANGE;

function clamp(v, lo, hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

function bandDist(db) {
    return N_DEPTHS > 1 ? db / (N_DEPTHS - 1) : 0; // 0 near .. 1 far
}

// How fast a band pans, as a multiple of the base speed: `near` for the closest
// band, `far` for the furthest. A wide spread is what makes the parallax read.
function panFactor(nearness, near, far) {
    return far + nearness * (near - far);
}

// Building heights trend upward toward the middle depth — big skyscrapers set
// back behind the foreground — then back down toward the far layers. Sizes stay
// random within a band; only the trend changes. Widths and gaps keep the
// perspective cue (nearer bands are wider and more spread out).
var TREND_PEAK = 0.5; // depth at which buildings are tallest
// Turrets sit on the range of taller buildings (not only the very tallest) so a
// few are usually on screen without being hidden behind nearer blocks.
var ANTENNA_MIN_HEIGHT = 0.16;

function sizeTrend(db) {
    var t = N_DEPTHS > 1 ? db / (N_DEPTHS - 1) : 0;
    if (t <= TREND_PEAK)
        return TREND_PEAK > 0 ? t / TREND_PEAK : 1;
    return (1 - t) / (1 - TREND_PEAK);
}

// Fraction of a building's windows that are lit. It follows the same middle-peaked
// trend as the heights — the tall centre towers glow, the low foreground stays
// mostly dark — with per-building randomness on top.
function litFraction(db, r) {
    return clamp(0.10 + sizeTrend(db) * 0.45 + r * 0.25, 0.05, 0.9);
}

// Window size as a fraction of the floor cell, from the building's relative
// height (`rel`: 0 short .. 1 tallest). The tallest buildings get the largest
// windows; variance grows as they get shorter, so small buildings vary a lot and
// only the big towers are consistently glazed. The floor grid never changes.
function windowScale(rel, r) {
    return clamp(1.0 - (1 - clamp(rel, 0, 1)) * (0.15 + 0.55 * (1 - r)), 0.3, 1.0);
}

// The tallest building covering screen x, as a height fraction (0 = nothing
// covers x, so the caller treats the screen bottom as the surface). `offsetsCells`
// is per-band scroll in cells and must include both the world offset and the
// band's continuous pan, or the collision ranges drift away from the drawn
// buildings and meteors fall through them.
function buildingHeightAt(skyline, x, offsetsCells, cellW, worldCells) {
    var maxH = 0;
    if (!skyline)
        return 0;
    var worldPx = worldCells * cellW;
    for (var db = 0; db < N_DEPTHS; ++db) {
        var buildings = skyline.layers[db];
        var off = offsetsCells[db] * cellW;
        for (var i = 0; i < buildings.length; ++i) {
            var bd = buildings[i];
            if (bd.h <= maxH)
                continue; // cannot raise the surface
            var bx = bd.x * cellW - off;
            for (var t = -1; t <= 1; ++t) {
                var x0 = bx + t * worldPx;
                if (x < x0 || x > x0 + bd.w * cellW)
                    continue;
                maxH = bd.h;
                break;
            }
        }
    }
    return maxH;
}

// Shortest signed angular difference from `from` to `to`, in (-pi, pi]. Used so a
// turret always turns the short way round rather than unwinding backwards.
function angleDiff(from, to) {
    var d = to - from;
    while (d > Math.PI)
        d -= 2 * Math.PI;
    while (d <= -Math.PI)
        d += 2 * Math.PI;
    return d;
}

// Step an aim toward `to` by at most `maxStep`, clamped to [minA, maxA]. The clamp
// is what stops a turret ever pointing downward.
function slewAim(from, to, maxStep, minA, maxA) {
    var d = angleDiff(from, to);
    if (d > maxStep)
        d = maxStep;
    else if (d < -maxStep)
        d = -maxStep;
    return clamp(from + d, minA, maxA);
}

// Meteors cross the sky on a downward heading (sin(angle) > 0), between 63 and
// 117 degrees, so each has its own direction but none travels upward.
var METEOR_MIN_ANGLE = Math.PI * 0.35;
var METEOR_MAX_ANGLE = Math.PI * 0.65;

function meteorDirection(rand) {
    return METEOR_MIN_ANGLE + rand() * (METEOR_MAX_ANGLE - METEOR_MIN_ANGLE);
}

// Distance from a point to a line segment. Used for missile-vs-meteor hits so a
// fast interceptor cannot tunnel through a slow meteor between two frames.
function segmentDistance(ax, ay, bx, by, px, py) {
    var dx = bx - ax;
    var dy = by - ay;
    var len2 = dx * dx + dy * dy;
    var t = len2 > 0 ? ((px - ax) * dx + (py - ay) * dy) / len2 : 0;
    t = clamp(t, 0, 1);
    var cx = ax + t * dx;
    var cy = ay + t * dy;
    return Math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

// A small burst. The particle count is random (0 to `maxCount`), each particle
// leaves at its own speed with a little angular jitter around an even ring, and
// gravity pulls them all down afterwards. `t0` is the clock value it was born at,
// which is what lets it expire.
function makeExplosion(x, y, maxCount, rand, speed, t0, gravity) {
    var n = Math.floor(rand() * (maxCount + 1));
    var parts = [];
    for (var i = 0; i < n; ++i) {
        var a = (i / n) * 6.283 + (rand() - 0.5) * 0.4;
        parts.push([a, speed * rand()]);
    }
    return {
        x: x,
        y: y,
        t0: t0,
        gravity: gravity,
        parts: parts
    };
}

// Where a particle is `age` seconds after the burst: straight-line ejection from
// the centre plus a ballistic drop.
function particleAt(e, part, age) {
    var a = part[0];
    var s = part[1];
    return [
        e.x + Math.cos(a) * s * age,
        e.y + Math.sin(a) * s * age + 0.5 * e.gravity * age * age
    ];
}

// Fail closed: an explosion with a missing or non-numeric t0 counts as expired,
// so a bad birth time can never leave it frozen on screen forever.
function explosionExpired(e, now, life) {
    return !(now - e.t0 <= life);
}

// The tallest a band's buildings get, as a fraction of screen height. The
// renderer uses it to size each band's canvas to just the strip it needs. It
// follows the middle-peaked size trend.
function bandMaxHeight(db) {
    return HEIGHT_MIN + sizeTrend(db) * HEIGHT_RANGE;
}

function rng(seed) {
    var s = seed >>> 0;
    return function () {
        s = (s + 0x6d2b79f5) >>> 0;
        var t = s;
        t = imul(t ^ (t >>> 15), t | 1);
        t ^= t + imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// Math.imul without relying on the built-in.
function imul(a, b) {
    var ah = (a >>> 16) & 0xffff;
    var al = a & 0xffff;
    return (al * b + (((ah * b) & 0xffff) << 16)) | 0;
}

function hash3(x, y, z) {
    var h = (x * 374761393) ^ (y * 668265263) ^ (z * 2246822519);
    h = imul(h ^ (h >>> 13), 1274126177);
    return (h ^ (h >>> 16)) & 0xffff;
}

// Buildings (in cells): x, width, heightFraction, dist (0 near .. 1 far), lit
// fraction, antenna. One array per depth band, nearest band first.
// Stars: xNorm, yNorm, magnitude, phase.
function makeSkyline(seed) {
    var rand = rng(seed);
    var layers = [];
    var bid = 0;
    for (var db = 0; db < N_DEPTHS; ++db) {
        var dist = bandDist(db);
        var nearness = 1 - dist;
        // Widths and gaps still follow distance (perspective): nearer bands have
        // few wide buildings, further bands many narrow ones. Height follows the
        // middle-peaked size trend instead, so the skyscrapers sit back a little.
        var wMin = 3 + Math.round(nearness * 8);
        var wMax = 7 + Math.round(nearness * 12);
        var hMin = 0.03 + sizeTrend(db) * 0.02;
        var hMax = bandMaxHeight(db);
        var gapBase = 2 + Math.round(nearness * 28);
        var buildings = [];
        var x = Math.floor(rand() * 6);
        while (x < WORLD_W) {
            var w = wMin + Math.floor(rand() * (wMax - wMin + 1));
            // Skewed short with occasional towers, so neighbours rarely match.
            var h = hMin + Math.pow(rand(), 1.8) * (hMax - hMin);
            var lit = litFraction(db, rand());
            var win = windowScale(h / MAX_BUILDING_HEIGHT, rand());
            // Turrets go only on the tallest buildings.
            var antenna = h >= ANTENNA_MIN_HEIGHT && rand() < 0.5 ? 1 : 0;
            buildings.push({
                x: x,
                w: w,
                h: h,
                dist: dist,
                lit: lit,
                win: win,
                antenna: antenna,
                bid: bid
            });
            bid++;
            x += w + gapBase + Math.floor(rand() * 4);
        }
        layers.push(buildings);
    }

    // Stars live on a large disc around the celestial pivot (filled in by the
    // renderer), so rotation always brings new ones in instead of emptying out.
    // Each: radiusFraction, angle, magnitude, twinklePhase.
    var stars = [];
    for (var s = 0; s < 1500; ++s)
        stars.push([Math.sqrt(rand()), rand() * 6.283, rand(), rand() * 6.283]);

    return {
        layers: layers,
        stars: stars,
        moon: [0.76 + rand() * 0.14, 0.09 + rand() * 0.1]
    };
}

// A window's base state is deterministic from its building's lit fraction. A
// separate sparse `flips` map overrides individual windows; toggling one window
// at a time (rather than re-rolling every window each frame) is cheaper and
// calmer.
function windowKey(bid, gx, gy) {
    return bid * 100003 + gx * 1009 + gy;
}

function baseOn(bid, gx, gy, lit) {
    return (hash3(bid * 131 + gx, gy, 11) % 1000) / 1000 < lit;
}

function windowOn(bid, gx, gy, lit, flips) {
    var f = flips[windowKey(bid, gx, gy)];
    return f === undefined ? baseOn(bid, gx, gy, lit) : f;
}

// Flip one random window in a random band; returns the band so the renderer can
// repaint just that one.
function toggleRandom(city, flips, rand, screenH, cellH) {
    var db = Math.floor(rand() * N_DEPTHS);
    var buildings = city.layers[db];
    if (buildings.length === 0)
        return db;
    var b = buildings[Math.floor(rand() * buildings.length)];
    var gx = Math.floor(rand() * b.w);
    var rows = Math.max(1, Math.floor(b.h * screenH / cellH));
    var gy = Math.floor(rand() * rows);
    flips[windowKey(b.bid, gx, gy)] = !windowOn(b.bid, gx, gy, b.lit, flips);
    return db;
}

// ---------------------------------------------------------------------------
// Modes
//
// Visibility and animation are a pure function of the mode and a small snapshot
// of machine state, so the policy can be tested without a compositor or battery.

var MODE_ALWAYS = 0;
var MODE_IDLE = 1;
var MODE_GREETER = 2;
var MODE_OFF = 3;

function modeFromString(s) {
    if (s === "idle")
        return MODE_IDLE;
    if (s === "greeter")
        return MODE_GREETER;
    if (s === "off")
        return MODE_OFF;
    return MODE_ALWAYS;
}

function modeName(mode) {
    switch (mode) {
    case MODE_IDLE:
        return "idle";
    case MODE_GREETER:
        return "greeter";
    case MODE_OFF:
        return "off";
    default:
        return "always";
    }
}

function shouldShow(mode, st) {
    switch (mode) {
    case MODE_OFF:
        return false;
    case MODE_GREETER:
        return !!st.isGreeter;
    case MODE_IDLE:
        return !!st.idle;
    default:
        return true;
    }
}

function shouldAnimate(mode, st) {
    if (!shouldShow(mode, st))
        return false;
    if (st.fullscreen)
        return false;
    if (st.pauseOnBattery && st.onBattery)
        return false;
    return true;
}
