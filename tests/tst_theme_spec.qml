import QtQuick
import QtTest
import Quilt.Controls

// Theme follows a ThemeSpec: switching specs, overriding tokens, the mode a
// one-mode theme forces, and borrowing another theme's feel.
Item {
    id: root
    width: 200
    height: 100

    ThemeSpec {
        id: paper
        name: "Paper"
        accent: dark ? "#ff7a45" : "#c2410c"
        canvas: dark ? "#201c18" : "#f4efe6"
        radius: 0
        controlHeight: 30
        duration: 300
        hoverReveal: false
    }
    ThemeSpec {
        id: night
        name: "Night"
        modes: ThemeSpec.DarkOnly
        surface: "#000000"
    }
    ThemeSpec {
        id: day
        name: "Day"
        modes: ThemeSpec.LightOnly
    }

    Binding { id: brand; target: Theme; property: "accent"; value: "#00aa55"; when: false }

    TestCase {
        name: "ThemeSpec"
        when: windowShown

        function cleanup() {
            brand.when = false;
            Theme.feel = null;
            Theme.spec = Theme.quilt;
            Theme.reduceMotion = false;
            Theme.dark = true;
        }

        function test_switching_specs() {
            const accent = String(Theme.accent);
            Theme.spec = paper;
            compare(Theme.accent, Qt.color("#ff7a45"));
            compare(Theme.radius, 0);
            compare(Theme.controlHeight, 30);
            compare(Theme.surface, Theme.quilt.surface);    // what Paper leaves alone stays Quilt's
            Theme.dark = false;
            compare(Theme.accent, Qt.color("#c2410c"));
            compare(Theme.canvas, Qt.color("#f4efe6"));
            Theme.spec = Theme.quilt;
            compare(Theme.dark, false);                     // the chosen mode carries over
            Theme.dark = true;
            compare(String(Theme.accent), accent);
            compare(Theme.radius, 8);
        }

        function test_binding_override_survives_a_switch_and_yields() {
            brand.when = true;
            compare(Theme.accent, Qt.color("#00aa55"));
            Theme.spec = paper;
            compare(Theme.accent, Qt.color("#00aa55"));
            brand.when = false;
            compare(Theme.accent, Qt.color("#ff7a45"));     // back to the theme's
        }

        function test_assigned_token_stays_pinned() {
            Theme.radius = 3;
            Theme.spec = paper;
            compare(Theme.radius, 3);
            Theme.spec = Theme.quilt;
            compare(Theme.radius, 3);
            Theme.radius = Qt.binding(() => Theme.spec.radius);
            compare(Theme.radius, 8);
        }

        function test_derived_tokens_follow_the_accent() {
            brand.when = true;
            const a = Qt.color("#00aa55");
            fuzzyCompare(Theme.selection.r, a.r, 0.01);
            fuzzyCompare(Theme.selection.g, a.g, 0.01);
            fuzzyCompare(Theme.selection.a, 0.18, 0.01);
            fuzzyCompare(Theme.textSelection.a, 0.38, 0.01);
            compare(Theme.focus, a);
            compare(Theme.fillInk, Theme.text);
        }

        function test_single_mode_themes_snap_and_restore() {
            Theme.dark = false;
            Theme.spec = night;
            compare(Theme.dark, true);
            compare(night.dark, true);
            compare(Theme.surface, Qt.color("#000000"));
            Theme.dark = false;                     // asking for light under a dark-only theme
            compare(Theme.dark, true);
            Theme.spec = day;
            compare(Theme.dark, false);
            Theme.spec = Theme.quilt;
            compare(Theme.dark, false);             // the mode chosen before Night
            compare(Theme.quilt.dark, false);
            compare(Theme.text, Qt.color("#1b1d21"));
        }

        function test_reduce_motion_zeroes_durations() {
            Theme.spec = paper;
            compare(Theme.duration, 300);
            Theme.reduceMotion = true;
            compare(Theme.durationFast, 0);
            compare(Theme.duration, 0);
            compare(Theme.durationLayout, 0);
            Theme.reduceMotion = false;
            compare(Theme.duration, 300);
        }

        function test_feel_affects_only_feel_tokens() {
            Theme.spec = paper;
            Theme.feel = Theme.quilt;
            compare(Theme.accent, Qt.color("#ff7a45"));     // the look is Paper's
            compare(Theme.radius, 0);
            compare(Theme.controlHeight, 24);               // the feel is Quilt's
            compare(Theme.duration, 120);
            compare(Theme.hoverReveal, true);
            Theme.feel = null;
            compare(Theme.controlHeight, 30);
            compare(Theme.hoverReveal, false);
        }

        function test_a_destroyed_spec_leaves_quilts_own() {
            const s = createTemporaryQmlObject('import Quilt.Style; ThemeSpec { accent: "#123456"; controlHeight: 40 }', root);
            Theme.spec = s;
            compare(Theme.accent, Qt.color("#123456"));
            Theme.feel = s;
            s.destroy();
            tryCompare(Theme, "spec", Theme.quilt);
            compare(Theme.accent, Theme.quilt.accent);
            compare(Theme.controlHeight, 24);
        }

        function test_grammar_is_never_themed() {
            Theme.spec = paper;
            compare(Theme.dragThreshold, 3);
            compare(Theme.coarseFactor, 10);
            compare(Theme.fineFactor, 0.1);
        }
    }
}
