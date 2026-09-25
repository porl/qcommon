import QtQuick
import QtTest
import "../qml/NightSkySim.js" as Sim

// Tests for the pure simulation and the wallpaper mode policy. The renderer is
// verified by eye on a real session; these cover the model and policy.
TestCase {
    name: "NightSkySim"

    function test_constants_are_sane() {
        // These are read by the renderer; a missing one silently empties a whole
        // colour array (which is how a whole starfield once vanished).
        verify(Sim.LEVELS > 0);
        verify(Sim.STAR_LEVELS > 0);
        verify(Sim.WORLD_W > 0);
    }

    function test_skyline_is_deterministic() {
        var a = Sim.makeSkyline(42);
        var b = Sim.makeSkyline(42);
        compare(a.layers.length, b.layers.length);
        for (var L = 0; L < a.layers.length; ++L) {
            compare(a.layers[L].length, b.layers[L].length);
            for (var i = 0; i < a.layers[L].length; ++i) {
                var x = a.layers[L][i];
                var y = b.layers[L][i];
                compare(x.x, y.x);
                compare(x.w, y.w);
                compare(x.h, y.h);
                compare(x.dist, y.dist);
                compare(x.lit, y.lit);
                compare(x.antenna, y.antenna);
            }
        }
        compare(a.stars.length, b.stars.length);
    }

    function test_skyline_varies_by_seed() {
        var a = Sim.makeSkyline(1);
        var b = Sim.makeSkyline(2);
        var same = a.layers[0].length === b.layers[0].length;
        for (var i = 0; same && i < a.layers[0].length; ++i) {
            if (a.layers[0][i].x !== b.layers[0][i].x || a.layers[0][i].w !== b.layers[0][i].w)
                same = false;
        }
        verify(!same);
    }

    function test_distances_are_in_range() {
        var city = Sim.makeSkyline(7);
        for (var L = 0; L < city.layers.length; ++L) {
            for (var i = 0; i < city.layers[L].length; ++i) {
                var d = city.layers[L][i].dist;
                verify(d >= 0 && d <= 1);
            }
        }
    }

    function test_window_on_is_deterministic() {
        var flips = ({});
        verify(Sim.windowOn(3, 2, 5, 0.6, flips) === Sim.windowOn(3, 2, 5, 0.6, flips));
    }

    function test_window_on_matches_lit_fraction() {
        var flips = ({});
        var on = 0;
        var total = 0;
        for (var gy = 0; gy < 20; ++gy) {
            for (var gx = 0; gx < 20; ++gx) {
                total++;
                if (Sim.windowOn(9, gx, gy, 0.5, flips))
                    on++;
            }
        }
        var frac = on / total;
        verify(frac > 0.3 && frac < 0.7);
    }

    function test_toggle_changes_one_window() {
        var city = Sim.makeSkyline(1);
        var flips = ({});
        var before = Sim.windowOn(3, 2, 2, 0.5, flips);
        var db = Sim.toggleRandom(city, flips, function () {
            return 0.5;
        }, 720, 9);
        verify(db >= 0 && db < Sim.N_DEPTHS);
        var n = 0;
        for (var k in flips)
            n++;
        compare(n, 1);
    }

    function test_show_policy() {
        var st = {
            isGreeter: false,
            idle: false,
            onBattery: false,
            fullscreen: false,
            pauseOnBattery: false
        };
        verify(Sim.shouldShow(Sim.MODE_ALWAYS, st));
        verify(!Sim.shouldShow(Sim.MODE_OFF, st));
        verify(!Sim.shouldShow(Sim.MODE_IDLE, st));
        verify(!Sim.shouldShow(Sim.MODE_GREETER, st));
        st.idle = true;
        verify(Sim.shouldShow(Sim.MODE_IDLE, st));
        st.isGreeter = true;
        verify(Sim.shouldShow(Sim.MODE_GREETER, st));
    }

    function test_animate_pauses() {
        var st = {
            isGreeter: false,
            idle: false,
            onBattery: false,
            fullscreen: false,
            pauseOnBattery: false
        };
        verify(Sim.shouldAnimate(Sim.MODE_ALWAYS, st));
        st.fullscreen = true;
        verify(!Sim.shouldAnimate(Sim.MODE_ALWAYS, st));
        st.fullscreen = false;
        st.onBattery = true;
        verify(Sim.shouldAnimate(Sim.MODE_ALWAYS, st));
        st.pauseOnBattery = true;
        verify(!Sim.shouldAnimate(Sim.MODE_ALWAYS, st));
    }

    function test_mode_names() {
        compare(Sim.modeName(Sim.MODE_IDLE), "idle");
        compare(Sim.modeName(Sim.MODE_OFF), "off");
        compare(Sim.modeFromString("greeter"), Sim.MODE_GREETER);
        compare(Sim.modeFromString("nonsense"), Sim.MODE_ALWAYS);
    }

    function test_meteor_direction_always_descends() {
        // Every meteor must travel somewhat downward: a direction with a positive
        // vertical component. 63-117 degrees keeps them between down-right and
        // down-left and never rising.
        var rand = Sim.rng(99);
        for (var i = 0; i < 500; ++i) {
            var d = Sim.meteorDirection(rand);
            verify(Math.sin(d) > 0);
            verify(d >= Sim.METEOR_MIN_ANGLE && d <= Sim.METEOR_MAX_ANGLE);
        }
    }

    function test_meteor_direction_varies() {
        var rand = Sim.rng(5);
        var first = Sim.meteorDirection(rand);
        var varied = false;
        for (var i = 0; i < 50 && !varied; ++i) {
            if (Sim.meteorDirection(rand) !== first)
                varied = true;
        }
        verify(varied);
    }

    function test_segment_distance() {
        // On the segment, beyond either end, and perpendicular to the middle.
        compare(Sim.segmentDistance(0, 0, 10, 0, 5, 0), 0);
        compare(Sim.segmentDistance(0, 0, 10, 0, -4, 0), 4);
        compare(Sim.segmentDistance(0, 0, 10, 0, 14, 0), 4);
        compare(Sim.segmentDistance(0, 0, 10, 0, 5, 3), 3);
    }

    function test_segment_distance_catches_tunnelling() {
        // A fast interceptor stepping right past a meteor must still register a
        // hit: the closest approach of the segment is 1px, though neither endpoint
        // is near.
        var d = Sim.segmentDistance(0, 0, 100, 0, 50, 1);
        verify(d <= 1.001);
    }

    function test_pan_factor_gives_parallax() {
        // Near bands move faster than far ones, by the given factors, monotonically
        // in between.
        compare(Sim.panFactor(1, 1.8, 0.15), 1.8);
        compare(Sim.panFactor(0, 1.8, 0.15), 0.15);
        var prev = -1;
        for (var n = 0; n <= 1.0001; n += 0.1) {
            var f = Sim.panFactor(n, 1.8, 0.15);
            verify(f > prev);
            prev = f;
        }
        verify(Sim.panFactor(1, 1.8, 0.15) > Sim.panFactor(0, 1.8, 0.15) * 5);
    }

    function test_size_trend_peaks_near_middle() {
        verify(Sim.sizeTrend(0) < 0.2);
        verify(Sim.sizeTrend(Sim.N_DEPTHS - 1) < 0.2);
        var mid = Math.round(Sim.TREND_PEAK * (Sim.N_DEPTHS - 1));
        verify(Sim.sizeTrend(mid) > 0.9);
        // Rises to the peak, then falls away.
        var prev = -1;
        for (var up = 0; up <= mid; ++up) {
            var vu = Sim.sizeTrend(up);
            verify(vu > prev);
            prev = vu;
        }
        prev = 2;
        for (var down = mid; down < Sim.N_DEPTHS; ++down) {
            var vd = Sim.sizeTrend(down);
            verify(vd < prev);
            prev = vd;
        }
    }

    function test_band_max_height_trends_to_middle() {
        var mid = Math.round(Sim.TREND_PEAK * (Sim.N_DEPTHS - 1));
        verify(Sim.bandMaxHeight(mid) > Sim.bandMaxHeight(0));
        verify(Sim.bandMaxHeight(mid) > Sim.bandMaxHeight(Sim.N_DEPTHS - 1));
    }

    function test_lit_fraction_follows_height_trend() {
        var mid = Math.round(Sim.TREND_PEAK * (Sim.N_DEPTHS - 1));
        compare(Sim.litFraction(mid, 0.5) > Sim.litFraction(0, 0.5), true);
        compare(Sim.litFraction(mid, 0.5) > Sim.litFraction(Sim.N_DEPTHS - 1, 0.5), true);
        // Randomness: the same band with different random draws differs.
        verify(Sim.litFraction(mid, 0) !== Sim.litFraction(mid, 1));
        // And it stays a valid fraction everywhere.
        for (var db = 0; db < Sim.N_DEPTHS; ++db) {
            for (var r = 0; r <= 1.0001; r += 0.25) {
                var v = Sim.litFraction(db, r);
                verify(v >= 0 && v <= 1);
            }
        }
    }

    function test_window_scale_tallest_largest() {
        // The tallest buildings have the largest windows, unconditionally.
        compare(Sim.windowScale(1, 0), 1.0);
        compare(Sim.windowScale(1, 1), 1.0);
        // A mid building's best case still cannot beat the tallest.
        verify(Sim.windowScale(1, 0) > Sim.windowScale(0.5, 1));
        // Variance grows as buildings get smaller.
        var spreadTall = Math.abs(Sim.windowScale(1, 0) - Sim.windowScale(1, 1));
        var spreadSmall = Math.abs(Sim.windowScale(0.1, 0) - Sim.windowScale(0.1, 1));
        verify(spreadTall < spreadSmall);
        for (var r = 0; r <= 1.0001; r += 0.5) {
            for (var rel = 0; rel <= 1.0001; rel += 0.5) {
                var v = Sim.windowScale(rel, r);
                verify(v >= 0.3 && v <= 1.0);
            }
        }
    }

    function test_angle_diff_takes_the_short_way() {
        // From just below +pi to just above -pi is a tiny step, not a full turn.
        verify(Math.abs(Sim.angleDiff(3.0, -3.0) - 0.2832) < 1e-3);
        verify(Math.abs(Sim.angleDiff(-3.0, 3.0) + 0.2832) < 1e-3);
        for (var i = 0; i < 50; ++i) {
            var a = -Math.PI + (i / 50) * 2 * Math.PI;
            var b = -Math.PI + (((i * 7) % 50) / 50) * 2 * Math.PI;
            verify(Math.abs(Sim.angleDiff(a, b)) <= Math.PI + 1e-9);
        }
    }

    function test_slew_aim_is_limited() {
        // A step is capped at maxStep.
        verify(Math.abs(Sim.slewAim(-0.1, -Math.PI / 2, 0.1, -Math.PI, 0) - -0.2) < 1e-9);
        verify(Math.abs(Sim.slewAim(-3.0, 0, 0.1, -Math.PI, 0) - -2.9) < 1e-9);
    }

    function test_slew_aim_never_points_down() {
        // Targets that would aim below the horizon clamp to horizontal, never down.
        verify(Sim.slewAim(-0.1, 1.0, 10, -Math.PI, 0) <= 0);
        verify(Sim.slewAim(-0.1, 3.0, 10, -Math.PI, 0) <= 0);
        verify(Sim.slewAim(-Math.PI, -1.0, 10, -Math.PI, 0) >= -Math.PI);
        for (var i = 0; i <= 20; ++i) {
            var aim = Sim.slewAim(-0.5, (i / 20) * Math.PI, 10, -Math.PI, 0);
            verify(aim <= 0 && aim >= -Math.PI);
        }
    }

    function test_turret_density_on_screen() {
        // Roughly three or four turrets should be in a screen-wide window, averaged
        // over the scroll, so most meteors meet a gun without it being a forest.
        var windowCells = 256; // 1280 px / 5 px cells
        var total = 0;
        var samples = 0;
        for (var seed = 1; seed <= 8; ++seed) {
            var city = Sim.makeSkyline(seed);
            for (var off = 0; off < 1400; off += 100) {
                var count = 0;
                for (var db = 0; db < Sim.N_DEPTHS; ++db) {
                    var bs = city.layers[db];
                    for (var i = 0; i < bs.length; ++i) {
                        if (!bs[i].antenna)
                            continue;
                        var x = bs[i].x - off;
                        x = ((x % 1400) + 1400) % 1400;
                        if (x < windowCells)
                            count++;
                    }
                }
                total += count;
                samples++;
            }
        }
        var avg = total / samples;
        verify(avg >= 2.5 && avg <= 5.5);
    }

    function test_building_height_at_x() {
        var city = Sim.makeSkyline(4);
        var cellW = 5;
        var worldPx = Sim.WORLD_W * cellW;
        var zeros = [];
        for (var db = 0; db < Sim.N_DEPTHS; ++db)
            zeros.push(0);

        // Pick a building with clear sky 100px to its left, so the shifted lookup
        // below is unambiguous.
        var chosen = null;
        for (var d = 0; d < Sim.N_DEPTHS && !chosen; ++d) {
            var bs = city.layers[d];
            for (var i = 0; i < bs.length; ++i) {
                var xs = (bs[i].x + bs[i].w / 2) * cellW;
                if (xs < 200)
                    continue;
                var covered = false;
                for (var d2 = 0; d2 < Sim.N_DEPTHS; ++d2) {
                    var bs2 = city.layers[d2];
                    for (var j = 0; j < bs2.length; ++j) {
                        for (var t = -1; t <= 1; ++t) {
                            var s = bs2[j].x * cellW - t * worldPx;
                            var e = (bs2[j].x + bs2[j].w) * cellW - t * worldPx;
                            if (xs - 100 >= s && xs - 100 <= e)
                                covered = true;
                        }
                    }
                }
                if (!covered) {
                    chosen = {
                        x: xs,
                        h: bs[i].h
                    };
                    break;
                }
            }
        }
        verify(chosen !== null);

        // On a building: at least that building's height.
        var onBuilding = Sim.buildingHeightAt(city, chosen.x, zeros, cellW, Sim.WORLD_W);
        verify(onBuilding >= chosen.h - 1e-9);

        // The surface at x depends on the scroll offset: the same building appears
        // 100px left once the offset grows by 20 cells, and is absent where it was.
        verify(Sim.buildingHeightAt(city, chosen.x - 100, zeros, cellW, Sim.WORLD_W) === 0);
        var shifted = [];
        for (var d3 = 0; d3 < Sim.N_DEPTHS; ++d3)
            shifted.push(20);
        verify(Sim.buildingHeightAt(city, chosen.x - 100, shifted, cellW, Sim.WORLD_W) >= chosen.h - 1e-9);
    }

    function test_turrets_only_on_tall_buildings() {
        var city = Sim.makeSkyline(11);
        var antennas = 0;
        var shorts = 0;
        for (var db = 0; db < Sim.N_DEPTHS; ++db) {
            var bs = city.layers[db];
            for (var i = 0; i < bs.length; ++i) {
                if (bs[i].antenna) {
                    antennas++;
                    verify(bs[i].h >= Sim.ANTENNA_MIN_HEIGHT);
                }
                if (bs[i].h < Sim.ANTENNA_MIN_HEIGHT)
                    shorts++;
            }
        }
        verify(antennas > 0);
        verify(shorts > 0);
    }

    function test_explosion_shape() {
        var rand = Sim.rng(3);
        var e = Sim.makeExplosion(10, 20, 7, rand, 50, 1.5, 40);
        compare(e.x, 10);
        compare(e.y, 20);
        compare(e.t0, 1.5);
        compare(e.gravity, 40);
        verify(e.parts.length <= 7);
        for (var i = 0; i < e.parts.length; ++i)
            verify(e.parts[i][1] >= 0 && e.parts[i][1] <= 50);
    }

    function test_explosion_particle_count_is_random_and_bounded() {
        var rand = Sim.rng(4);
        var seenEmpty = false;
        var seenFull = false;
        for (var i = 0; i < 600; ++i) {
            var e = Sim.makeExplosion(0, 0, 10, rand, 24, 0, 40);
            verify(e.parts.length >= 0 && e.parts.length <= 10);
            if (e.parts.length === 0)
                seenEmpty = true;
            if (e.parts.length === 10)
                seenFull = true;
        }
        verify(seenEmpty);
        verify(seenFull);
    }

    function test_explosion_is_ringlike() {
        // Angular jitter must not collapse the burst into a clump: gaps around the
        // circle stay a decent fraction of an even step.
        var rand = Sim.rng(8);
        var checked = 0;
        for (var k = 0; k < 300 && checked < 25; ++k) {
            var e = Sim.makeExplosion(0, 0, 10, rand, 25, 0, 40);
            var n = e.parts.length;
            if (n < 3)
                continue;
            var angs = [];
            for (var i = 0; i < n; ++i)
                angs.push(e.parts[i][0]);
            angs.sort(function (a, b) {
                return a - b;
            });
            var step = 6.283 / n;
            for (var j = 0; j < n; ++j) {
                var gap = j === n - 1 ? angs[0] + 6.283 - angs[n - 1] : angs[j + 1] - angs[j];
                verify(gap > step * 0.4);
            }
            checked++;
        }
        verify(checked > 0);
    }

    function test_explosion_particles_fall_under_gravity() {
        var rand = Sim.rng(1);
        var e = null;
        for (var k = 0; k < 50 && (!e || e.parts.length === 0); ++k)
            e = Sim.makeExplosion(0, 0, 10, rand, 24, 0, 40);
        verify(e.parts.length > 0);
        var p = e.parts[0];
        var age = 0.7;
        var q = Sim.particleAt(e, p, age);
        var straight = e.y + Math.sin(p[0]) * p[1] * age;
        verify(Math.abs(q[1] - (straight + 0.5 * e.gravity * age * age)) < 1e-9);
        verify(q[1] > straight);
        // With no gravity it is a straight line.
        var g0 = Sim.makeExplosion(0, 0, 10, rand, 24, 0, 0);
        if (g0.parts.length > 0) {
            var p0 = g0.parts[0];
            var q0 = Sim.particleAt(g0, p0, 0.5);
            verify(Math.abs(q0[1] - (g0.y + Math.sin(p0[0]) * p0[1] * 0.5)) < 1e-9);
        }
    }

    function test_explosion_expires() {
        var e = Sim.makeExplosion(0, 0, 4, Sim.rng(1), 30, 10);
        verify(!Sim.explosionExpired(e, 10.5, 1));
        verify(!Sim.explosionExpired(e, 11.0, 1));
        verify(Sim.explosionExpired(e, 11.0 + 1e-6, 1));
        verify(Sim.explosionExpired(e, 20, 1));
    }

    function test_explosion_without_birth_time_is_expired() {
        // Fail closed: a missing t0 must not leave a burst frozen on screen, which
        // is exactly what happened when makeExplosion forgot to set it.
        var e = Sim.makeExplosion(0, 0, 4, Sim.rng(1), 30, undefined);
        verify(Sim.explosionExpired(e, 0, 1));
        verify(Sim.explosionExpired(e, 999, 1));
    }
}
