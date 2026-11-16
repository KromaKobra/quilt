import QtQuick
import QtTest
import Quilt.Controls

// NumberField: the interaction grammar from docs/controls.md, exercised
// with simulated mouse, wheel and keys.
Item {
    id: root
    width: 420
    height: 400

    property real m: 10                     // the application's value
    property var log: []                    // what the transaction signals reported

    Component {
        id: bound
        NumberField {
            width: 200
            value: root.m
            onEditStarted: root.log.push("start")
            onEdited: v => { root.log.push(v); root.m = v; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }
    Component { id: plain; NumberField { width: 200 } }

    TestCase {
        name: "NumberField"
        when: windowShown

        function init() {
            root.m = 10;
            root.log = [];
        }

        function make(component, properties) {
            const field = createTemporaryObject(component, root, properties || {});
            verify(field);
            return field;
        }

        function type(text) {
            for (const ch of text)
                keyClick(ch);
        }

        // Presses at x and drags right by `distance`, in small steps.
        function drag(field, distance, modifiers) {
            const mods = modifiers || Qt.NoModifier;
            mousePress(field, 50, 12, Qt.LeftButton, mods);
            const dir = distance < 0 ? -1 : 1;
            for (let d = 1; d <= Math.abs(distance); ++d)
                mouseMove(field, 50 + dir * d, 12, -1, Qt.LeftButton, mods);
        }

        function signals() { return root.log.filter(x => typeof x === "string"); }

        // ---- click and type

        function test_click_starts_editing_and_changes_nothing() {
            const f = make(bound);
            mouseClick(f, 50, 12);
            verify(f.editing);
            keyClick(Qt.Key_Return);
            verify(!f.editing);
            compare(root.m, 10);
            compare(root.log, []);
        }

        function test_entering_and_leaving_keeps_full_precision() {
            const f = make(plain, { value: 1 / 3, decimals: 2 });
            compare(f.displayText, "0.33");
            mouseClick(f, 50, 12);
            keyClick(Qt.Key_Return);
            compare(f.value, 1 / 3);
        }

        function test_typing_replaces_the_value() {
            const f = make(bound);
            mouseClick(f, 50, 12);
            type("42");
            compare(root.m, 10);                // nothing is applied before Enter
            keyClick(Qt.Key_Return);
            compare(root.m, 42);
            compare(root.log, ["start", 42, "commit"]);
        }

        function test_arithmetic() {
            const f = make(bound);
            const cases = [["2*21", 42], ["(120+48)/2", 84], ["+=10", 94], ["-=4", 90], ["*=2", 180], ["/=4", 45],
                           ["-5", -5], ["1,5", 1.5], ["sqrt(16)", 4]];
            for (const c of cases) {
                mouseClick(f, 50, 12);
                type(c[0]);
                keyClick(Qt.Key_Return);
                compare(root.m, c[1], c[0]);
            }
        }

        function test_invalid_text_is_kept_until_fixed_or_cancelled() {
            const f = make(bound);
            mouseClick(f, 50, 12);
            type("2*(");
            keyClick(Qt.Key_Return);
            verify(f.editing);                  // still editing: the text is not thrown away
            compare(root.m, 10);
            type("4)");
            keyClick(Qt.Key_Return);
            verify(!f.editing);
            compare(root.m, 8);

            mouseClick(f, 50, 12);
            type("nonsense");
            keyClick(Qt.Key_Escape);
            verify(!f.editing);
            compare(root.m, 8);
        }

        function test_clicking_away_commits_and_never_traps_focus() {
            const f = make(bound);
            const other = make(plain, { y: 40 });
            mouseClick(f, 50, 12);
            type("33");
            mouseClick(other, 50, 12);
            compare(root.m, 33);
            verify(!f.editing);
            verify(other.editing);
            keyClick(Qt.Key_Escape);

            mouseClick(f, 50, 12);
            type("1+");                         // can't be understood: dropped, not applied
            mouseClick(other, 50, 12);
            verify(!f.editing);
            compare(root.m, 33);
        }

        function test_tab_commits_and_moves_on() {
            const f = make(bound);
            const other = make(plain, { y: 40 });
            mouseClick(f, 50, 12);
            type("12");
            keyClick(Qt.Key_Tab);
            compare(root.m, 12);
            verify(!f.editing);
            verify(other.activeFocus);
            keyClick(Qt.Key_Backtab);
            verify(f.activeFocus);
        }

        function test_suffix_scale_and_units() {
            const f = make(plain, { value: 0.62, displayScale: 100, suffix: "%", decimals: 0 });
            compare(f.displayText, "62");
            mouseClick(f, 50, 12);
            type("50%");                        // the field's own suffix is accepted and ignored
            keyClick(Qt.Key_Return);
            compare(f.value, 0.5);

            const metres = make(plain, { y: 40, suffix: " m", units: { cm: 0.01, mm: 0.001 } });
            mouseClick(metres, 50, 12);
            type("5cm");
            keyClick(Qt.Key_Return);
            compare(metres.value, 0.05);
            mouseClick(metres, 50, 12);
            type("2 m");
            keyClick(Qt.Key_Return);
            compare(metres.value, 2);
        }

        function test_int_rounds_and_hard_limits_clamp() {
            const f = make(plain, { integer: true, minimum: 0, maximum: 100 });
            mouseClick(f, 50, 12);
            type("2.7");
            keyClick(Qt.Key_Return);
            compare(f.value, 3);
            mouseClick(f, 50, 12);
            type("500");
            keyClick(Qt.Key_Return);
            compare(f.value, 100);
            mouseClick(f, 50, 12);
            type("-3");
            keyClick(Qt.Key_Return);
            compare(f.value, 0);
        }

        function test_typing_may_leave_the_soft_range() {
            const f = make(plain, { from: 0, to: 1, maximum: 5, value: 0.5 });
            mouseClick(f, 50, 12);
            type("3");
            keyClick(Qt.Key_Return);
            compare(f.value, 3);                // beyond `to`, within `maximum`
            compare(f.position, 1);
            mouseClick(f, 50, 12);
            type("9");
            keyClick(Qt.Key_Return);
            compare(f.value, 5);
        }

        function test_custom_text_conversion() {
            const names = ["zero", "one", "two", "three"];
            const f = make(plain, {
                integer: true, value: 2,
                textFromValue: v => names[v] ?? String(v),
                valueFromText: t => names.indexOf(t) >= 0 ? names.indexOf(t) : Number(t)
            });
            compare(f.displayText, "two");
            mouseClick(f, 50, 12);
            keyClick("a", Qt.ControlModifier);
            type("three");
            keyClick(Qt.Key_Return);
            compare(f.value, 3);
        }

        // ---- drag

        function test_drag_threshold_and_no_jump() {
            const f = make(bound);
            mousePress(f, 50, 12);
            mouseMove(f, 52, 12);
            verify(!f.scrubbing);               // under 3 px: still a click
            compare(root.m, 10);
            mouseMove(f, 53, 12);
            verify(f.scrubbing);
            compare(root.m, 10);                // the value starts from the threshold: no jump
            mouseMove(f, 73, 12);
            compare(root.m, 11);                // 2 px per step of 0.1
            mouseMove(f, 93, 12);
            compare(root.m, 12);
            mouseRelease(f, 93, 12);
            compare(signals(), ["start", "commit"]);
            verify(!f.activeFocus);             // a drag leaves no focus behind
            verify(!f.editing);
        }

        function test_drag_lands_on_whole_steps() {
            const f = make(bound);
            drag(f, 40);
            mouseRelease(f);
            for (const v of root.log.filter(x => typeof x === "number"))
                compare(v, Math.round(v * 10) / 10);    // never 0.30000000000000004
        }

        function test_drag_modifiers() {
            const f = make(bound);
            drag(f, 23, Qt.ShiftModifier);      // 20 px past the threshold, ten times as fast
            compare(root.m, 20);
            mouseRelease(f);

            root.m = 10;
            drag(f, 23, Qt.ControlModifier);    // a tenth of the speed, on a finer grid
            compare(root.m, 10.1);
            mouseRelease(f);
        }

        function test_modifier_can_change_mid_drag_without_a_jump() {
            const f = make(bound);
            drag(f, 23);
            compare(root.m, 11);
            mouseMove(f, 74, 12, -1, Qt.LeftButton, Qt.ShiftModifier);
            verify(Math.abs(root.m - 11.5) < 1e-9);     // one more pixel, at ten times the speed
            mouseRelease(f);
        }

        function test_escape_cancels_a_drag() {
            const f = make(bound);
            drag(f, 43);
            verify(root.m !== 10);
            keyClick(Qt.Key_Escape);
            compare(root.m, 10);
            mouseMove(f, 150, 12, -1, Qt.LeftButton);   // the rest of this drag is ignored
            compare(root.m, 10);
            mouseRelease(f, 150, 12);
            compare(signals(), ["start", "cancel"]);
            compare(root.log[root.log.length - 2], 10);     // the start value was reported before the cancel
        }

        function test_vertical_movement_is_not_a_drag() {
            const f = make(bound);
            mousePress(f, 50, 12);
            mouseMove(f, 51, 20);
            mouseMove(f, 80, 60);
            mouseRelease(f, 80, 60);
            compare(root.m, 10);
            verify(!f.editing);
            compare(root.log, []);
        }

        function test_ranged_drag_covers_the_range_without_dead_travel() {
            const f = make(plain, { from: 0, to: 1, value: 0.5 });
            mousePress(f, 100, 12);
            mouseMove(f, 104, 12);
            mouseMove(f, 500, 12);              // far past the end
            compare(f.value, 1);
            mouseMove(f, 490, 12);              // turning back takes effect at once
            verify(f.value < 1);
            mouseRelease(f, 490, 12);

            f.value = 0;
            mousePress(f, 20, 12);
            mouseMove(f, 23, 12);
            mouseMove(f, 23 + 200, 12);         // one field width (at least 160 px) is the whole range
            compare(f.value, 1);
            mouseRelease(f, 223, 12);
        }

        function test_wrap() {
            const f = make(plain, { from: 0, to: 360, wrap: true, value: 350, step: 1 });
            f.forceActiveFocus(Qt.TabFocusReason);
            for (let i = 0; i < 15; ++i)
                keyClick(Qt.Key_Up);
            compare(f.value, 5);
            for (let i = 0; i < 10; ++i)
                keyClick(Qt.Key_Down);
            compare(f.value, 355);
        }

        function test_logarithmic() {
            const f = make(plain, { from: 10, to: 1000, logarithmic: true, value: 100 });
            fuzzyCompare(f.position, 0.5, 1e-9);
            f.value = 10;
            compare(f.position, 0);
            mousePress(f, 20, 12);
            mouseMove(f, 23, 12);
            mouseMove(f, 123, 12);              // half the field: the geometric middle
            fuzzyCompare(f.value, 100, 1e-6);
            mouseRelease(f, 123, 12);
        }

        function test_live_false_reports_once() {
            const f = make(bound, { live: false });
            drag(f, 43);
            compare(root.m, 10);                // nothing reported during the drag…
            compare(f.displayText, "12");       // …but the field shows where it is
            mouseRelease(f);
            compare(root.m, 12);
            compare(root.log, ["start", 12, "commit"]);
        }

        // ---- keys and wheel

        function test_arrow_keys_step() {
            const f = make(bound);
            f.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            compare(root.m, 10.1);
            keyClick(Qt.Key_Up, Qt.ShiftModifier);
            compare(root.m, 11);                // lands on a multiple of the coarse step
            keyClick(Qt.Key_Down, Qt.ControlModifier);
            compare(root.m, 10.99);
            keyClick(Qt.Key_PageUp);
            compare(root.m, 11.9);
            compare(signals(), ["start"]);      // a run of steps is one transaction
            keyClick(Qt.Key_Escape);
            compare(root.m, 10);
            compare(signals(), ["start", "cancel"]);
        }

        function test_a_run_of_steps_ends_after_a_pause_or_on_focus_loss() {
            const f = make(bound);
            const other = make(plain, { y: 40 });
            f.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            keyClick(Qt.Key_Up);
            compare(signals(), ["start"]);
            tryVerify(() => signals().length === 2, 2000);
            compare(signals(), ["start", "commit"]);

            keyClick(Qt.Key_Up);
            other.forceActiveFocus(Qt.TabFocusReason);
            compare(signals(), ["start", "commit", "start", "commit"]);
        }

        function test_typing_on_a_focused_field_replaces() {
            const f = make(bound);
            f.forceActiveFocus(Qt.TabFocusReason);
            type("7");
            verify(f.editing);
            type("5");
            keyClick(Qt.Key_Return);
            compare(root.m, 75);

            keyClick(Qt.Key_F2);                // edit what is there
            verify(f.editing);
            keyClick(Qt.Key_End);
            type("0");
            keyClick(Qt.Key_Return);
            compare(root.m, 750);
        }

        function test_up_and_down_work_while_typing() {
            const f = make(bound);
            mouseClick(f, 50, 12);
            type("20");
            keyClick(Qt.Key_Up);                // applies the text, then steps
            compare(root.m, 20.1);
            verify(f.editing);
            keyClick(Qt.Key_Escape);
        }

        function test_home_and_end_in_a_range() {
            const f = make(plain, { from: 0, to: 10, value: 4 });
            f.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_End);
            compare(f.value, 10);
            keyClick(Qt.Key_Home);
            compare(f.value, 0);
        }

        function test_wheel_needs_focus() {
            const f = make(bound);
            mouseWheel(f, 50, 12, 0, 120);
            compare(root.m, 10);                // scrolling past: nothing happens
            compare(root.log, []);
            f.forceActiveFocus(Qt.TabFocusReason);
            mouseWheel(f, 50, 12, 0, 120);
            compare(root.m, 10.1);
            mouseWheel(f, 50, 12, 0, -120, Qt.NoButton, Qt.ShiftModifier);
            compare(root.m, 10);                // a coarse step down, onto a multiple of it
        }

        function test_wheel_steps_are_whole_notches() {
            const f = make(bound);
            f.forceActiveFocus(Qt.TabFocusReason);
            mouseWheel(f, 50, 12, 0, 40);       // a high-resolution wheel: thirds of a notch
            mouseWheel(f, 50, 12, 0, 40);
            compare(root.m, 10);
            mouseWheel(f, 50, 12, 0, 40);
            compare(root.m, 10.1);
        }

        // ---- stepper buttons

        function test_stepper_buttons() {
            const f = make(plain, { integer: true, steppers: true, value: 5, minimum: 0, maximum: 7 });
            mouseClick(f, f.width - 10, 12);
            compare(f.value, 6);
            mouseClick(f, 10, 12);
            mouseClick(f, 10, 12);
            compare(f.value, 4);
            verify(!f.editing);
            mouseClick(f, 100, 12);             // the middle still types
            verify(f.editing);
            keyClick(Qt.Key_Escape);

            mousePress(f, f.width - 10, 12);    // holding repeats, up to the limit
            tryCompare(f, "value", 7, 3000);
            mouseRelease(f, f.width - 10, 12);
        }

        // ---- the application owns the value

        function test_refused_edit_snaps_back() {
            const f = make(plain, { value: Qt.binding(() => root.m) });     // nobody handles `edited`
            mouseClick(f, 50, 12);
            type("99");
            keyClick(Qt.Key_Return);
            compare(root.m, 10);
            compare(f.value, 10);
            compare(f.displayText, "10");
            root.m = 11;                        // and the binding is still alive
            compare(f.value, 11);
        }

        Component {
            id: clamping
            NumberField {
                width: 200
                value: root.m
                onEdited: v => root.m = Math.min(v, 50)     // the application has its own limit
            }
        }

        function test_shows_what_the_application_made_of_the_edit() {
            const f = make(clamping);
            mouseClick(f, 50, 12);
            type("500");
            keyClick(Qt.Key_Return);
            compare(root.m, 50);
            compare(f.value, 50);
        }

        function test_unbound_control_keeps_its_own_value() {
            const f = make(plain);
            mouseClick(f, 50, 12);
            type("8");
            keyClick(Qt.Key_Return);
            compare(f.value, 8);
        }

        // ---- parameter states

        function test_modified_and_reset() {
            const f = make(bound, { defaultValue: 10 });
            verify(!f.modified);
            root.m = 12;
            verify(f.modified);
            f.reset();
            compare(root.m, 10);
            verify(!f.modified);
            compare(signals(), ["start", "commit"]);
        }

        function test_driven_cannot_be_scrubbed_or_stepped() {
            const f = make(bound, { paramState: Param.Driven, expression: "width / 2", acceptsExpressions: true });
            let expression = null;
            f.expressionEdited.connect(text => expression = text);
            verify(!f.canScrub);
            drag(f, 40);
            mouseRelease(f);
            compare(root.m, 10);
            f.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            mouseWheel(f, 50, 12, 0, 120);
            compare(root.m, 10);

            // Editing shows the expression; changing it reports the new one.
            keyClick(Qt.Key_Return);
            verify(f.editing);
            keyClick(Qt.Key_End);
            type("+1");
            keyClick(Qt.Key_Return);
            compare(expression, "width / 2+1");
            compare(root.m, 10);
        }

        function test_equals_starts_an_expression_only_when_supported() {
            const f = make(bound, { acceptsExpressions: true });
            let expression = null;
            f.expressionEdited.connect(text => expression = text);
            mouseClick(f, 50, 12);
            type("=cube.width/2");
            keyClick(Qt.Key_Return);
            compare(expression, "cube.width/2");
            compare(root.m, 10);

            const plainField = make(bound, { y: 40 });      // no support: "=2*4" is just arithmetic
            mouseClick(plainField, 50, 12);
            type("=2*4");
            keyClick(Qt.Key_Return);
            compare(root.m, 8);
        }

        function test_mixed() {
            const f = make(bound, { paramState: Param.Mixed });
            compare(f.displayText, "Mixed");
            verify(!f.canScrub);
            f.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            compare(root.log, []);
            mouseClick(f, 50, 12);              // typing a value sets it for all
            type("5");
            keyClick(Qt.Key_Return);
            compare(root.m, 5);
        }

        function test_read_only_and_disabled() {
            const f = make(bound, { readOnly: true });
            mouseClick(f, 50, 12);
            verify(!f.editing);
            drag(f, 40);
            mouseRelease(f);
            f.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            type("5");
            compare(root.log, []);

            const off = make(bound, { y: 40, enabled: false });
            mouseClick(off, 50, 12);
            verify(!off.editing);
            compare(root.log, []);
        }

        // ---- parameter objects

        Component {
            id: duck
            QtObject {
                property real value: 4
                property real defaultValue: 4
                property var calls: []
                function setValue(v) { calls.push("set"); value = Math.min(v, 9); }
                function beginEdit() { calls.push("begin"); }
                function endEdit(committed) { calls.push(committed ? "end" : "cancel"); }
            }
        }

        function test_parameter_object() {
            const p = createTemporaryObject(duck, root);
            const f = make(plain, { param: p });
            compare(f.value, 4);
            verify(!f.modified);
            mouseClick(f, 50, 12);
            type("7");
            keyClick(Qt.Key_Return);
            compare(p.value, 7);
            compare(f.value, 7);
            verify(f.modified);
            compare(p.calls, ["begin", "set", "end"]);
            mouseClick(f, 50, 12);
            type("70");
            keyClick(Qt.Key_Return);
            compare(f.value, 9);                // the parameter's own limit shows
            p.value = 2;                        // a change from elsewhere shows too
            compare(f.value, 2);
            f.reset();
            compare(p.value, 4);
        }

        function test_copy_and_paste_text() {
            const f = make(bound, { displayScale: 100, suffix: "%" });
            root.m = 0.25;
            compare(f.copyText(), "25");
            f.pasteText("40");
            compare(root.m, 0.4);
            f.pasteText("not a number");
            compare(root.m, 0.4);
        }
    }
}
