import QtQuick
import QtTest
import Quilt.Controls
import Quilt.Params

// Quilt.Params: expressions between parameters, and controls bound to them.
Item {
    id: root
    width: 420
    height: 300

    property var log: []

    Component {
        id: setComponent
        ParameterSet {
            Parameter { name: "cube.width"; value: 100; defaultValue: 100 }
            Parameter { name: "cube.height"; value: 10; expression: "width / 2" }      // a sibling, by its short name
            Parameter { name: "cube.position"; value: Qt.vector3d(1, 2, 3) }
            Parameter { name: "cube.fill"; type: "color"; value: Qt.rgba(1, 0, 0, 1) }
            Parameter { name: "cube.name"; type: "string"; value: "Cube" }
            Parameter { name: "ball.size"; expression: "cube.width + cube.height + cube.position.z" }
            Parameter { name: "ball.on"; value: false; expression: "cube.width > 150" }
            Parameter { name: "ball.count"; type: "int"; value: 1 }

            onEditStarted: p => root.log.push("start " + p.name)
            onEditFinished: (p, committed) => root.log.push((committed ? "commit " : "cancel ") + p.name)
        }
    }

    Component { id: numberField; NumberField { width: 200 } }
    Component { id: textField; TextField { width: 200 } }
    Component { id: checkBox; CheckBox { } }
    Component { id: merged; MergedParameter { } }
    Component { id: row; PropertyRow { width: 400; label: "Value"; NumberField { } } }
    // A stand-in for a viewport: clicking it changes the selection, and
    // takes no keyboard focus.
    Component {
        id: viewport
        Rectangle {
            width: 200; height: 100; y: 150
            signal tapped()
            TapHandler { onTapped: parent.tapped() }
        }
    }
    Component { id: parameter; Parameter { } }

    TestCase {
        name: "Params"
        when: windowShown

        property var set: null

        function init() {
            root.log = [];
            set = createTemporaryObject(setComponent, root);
            verify(set);
        }

        function make(component, properties) {
            const item = createTemporaryObject(component, root, properties || {});
            verify(item);
            return item;
        }

        function type(text) {
            for (const ch of text)
                keyClick(ch);
        }

        function p(name) {
            const found = set.find(name);
            verify(found, name);
            return found;
        }

        // ---- the engine

        function test_expressions_are_evaluated_at_start() {
            compare(set.count, 8);
            compare(p("cube.height").value, 50);
            compare(p("ball.size").value, 153);
            compare(p("ball.on").value, false);
            compare(p("cube.height").state, Param.Driven);
            compare(p("cube.height").message, "= width / 2");
            compare(p("cube.width").state, Param.Normal);
        }

        function test_changes_reach_everything_downstream() {
            p("cube.width").setValue(200);
            compare(p("cube.height").value, 100);
            compare(p("ball.size").value, 303);
            compare(p("ball.on").value, true);          // a comparison coerced to this parameter's bool
            p("cube.position").setValue(Qt.vector3d(0, 0, 10));     // a component of a vector
            compare(p("ball.size").value, 310);
        }

        function test_direct_writes_to_value_propagate_too() {
            p("cube.width").value = 40;                 // an animation or a tool, not a control
            compare(p("cube.height").value, 20);
        }

        function test_each_parameter_is_evaluated_once_and_in_order() {
            // A diamond: d reads b and c, which both read a. d must never
            // be computed from a new b and an old c.
            const a = make(parameter, { name: "a", value: 1 });
            const b = make(parameter, { name: "b", expression: "a + 1" });
            const c = make(parameter, { name: "c", expression: "a * 10" });
            const d = make(parameter, { name: "d", expression: "b + c" });
            for (const x of [a, b, c, d])
                verify(set.add(x));
            compare(d.value, 12);
            const seen = [];
            const watch = q => { if (q === d) seen.push(d.value); };
            set.changed.connect(watch);
            a.setValue(2);
            set.changed.disconnect(watch);
            compare(d.value, 23);
            compare(seen, [23]);                        // once, with both inputs up to date
        }

        function test_setting_a_value_removes_the_expression() {
            const h = p("cube.height");
            h.setValue(7);
            compare(h.expression, "");
            compare(h.state, Param.Normal);
            compare(h.value, 7);
            p("cube.width").setValue(500);
            compare(h.value, 7);                        // no longer follows
        }

        function test_removing_an_expression_keeps_the_value() {
            const h = p("cube.height");
            h.setExpression("");
            compare(h.value, 50);
            compare(h.state, Param.Normal);
        }

        function test_int_and_bool_results_are_coerced() {
            const n = p("ball.count");
            n.setExpression("cube.width / 3");
            compare(n.value, 33);
            n.setValue(2.6);
            compare(n.value, 3);
        }

        function test_errors_keep_the_last_good_value() {
            const w = p("cube.width");
            w.setExpression("nope + 1");
            compare(w.state, Param.Invalid);
            compare(w.message, "Unknown name: nope");
            compare(w.value, 100);
            w.setExpression("2 *");
            compare(w.state, Param.Invalid);
            compare(w.message, "Incomplete expression");
            w.setExpression("toString");                // inherited JavaScript names are not parameters
            compare(w.message, "Unknown name: toString");
            w.setExpression("50 * 2 + 1");
            compare(w.state, Param.Driven);
            compare(w.value, 101);
        }

        function test_cycles_are_refused() {
            const w = p("cube.width");
            w.setExpression("ball.size");               // ball.size reads cube.width
            compare(w.state, Param.Invalid);
            compare(w.message, "Circular reference");
            compare(w.value, 100);
            compare(p("ball.size").state, Param.Driven);    // the rest carries on
            w.setExpression("cube.width + 1");          // itself
            compare(w.message, "Circular reference");

            // Opening the cycle elsewhere makes it valid again.
            w.setExpression("ball.size");
            p("ball.size").setExpression("7");
            compare(w.state, Param.Driven);
            compare(w.value, 7);
        }

        function test_reset() {
            const w = p("cube.width");
            w.setExpression("3");
            w.reset();
            compare(w.expression, "");
            compare(w.value, 100);
        }

        function test_read_only() {
            const w = p("cube.width");
            w.readOnly = true;
            w.setValue(5);
            w.setExpression("1");
            w.reset();
            compare(w.value, 100);
            compare(w.expression, "");
        }

        function test_add_and_remove() {
            const late = make(parameter, { name: "late.value", expression: "missing.thing * 2" });
            verify(set.add(late));
            compare(late.state, Param.Invalid);
            const thing = make(parameter, { name: "missing.thing", value: 21 });
            verify(set.add(thing));                     // what was waiting for the name gets it
            compare(late.state, Param.Driven);
            compare(late.value, 42);
            compare(set.find("late.value"), late);
            compare(set.list("late.").length, 1);

            ignoreWarning(/a Parameter needs a unique name/);
            verify(!set.add(make(parameter, { name: "late.value" })));

            set.remove(thing);
            compare(set.find("missing.thing"), null);
            compare(late.state, Param.Invalid);
            compare(late.value, 42);
        }

        function test_find_is_not_fooled_by_inherited_names() {
            compare(set.find("constructor"), null);
            compare(set.find("toString"), null);
        }

        function test_save_and_restore() {
            const w = p("cube.width"), h = p("cube.height");
            const saved = set.save();
            const text = JSON.stringify(saved);         // plain data all the way down
            w.setValue(5);
            h.setExpression("width + 1");
            p("cube.position").setValue(Qt.vector3d(9, 9, 9));
            p("cube.fill").setValue(Qt.rgba(0, 0, 1, 0.5));
            p("cube.name").setValue("Other");
            set.restore(JSON.parse(text));
            compare(w.value, 100);
            compare(h.expression, "width / 2");
            compare(h.value, 50);
            compare(p("cube.position").value, Qt.vector3d(1, 2, 3));
            compare(p("cube.fill").value, Qt.rgba(1, 0, 0, 1));
            compare(p("cube.name").value, "Cube");
            compare(p("ball.size").value, 153);
        }

        // ---- controls on parameters

        function test_field_shows_and_edits_a_parameter() {
            const w = p("cube.width");
            const f = make(numberField, { param: w });
            compare(f.value, 100);
            verify(!f.modified);
            mouseClick(f, 50, 12);
            type("120");
            keyClick(Qt.Key_Return);
            compare(w.value, 120);
            verify(f.modified);
            compare(root.log, ["start cube.width", "commit cube.width"]);
            f.reset();
            compare(w.value, 100);
        }

        // The row menu's linking items: copy one parameter's reference,
        // paste it onto another as a link, edit and remove the link.
        function test_row_menu_links_parameters() {
            const source = make(row);
            source.control.param = p("cube.width");
            const target = make(row, { y: 40 });
            target.control.param = p("ball.count");

            function open(r) {
                mouseClick(r, 30, 14, Qt.RightButton);
                const menu = findChild(r, "rowMenu");
                verify(menu);
                tryVerify(() => menu.opened);
                return menu;
            }
            function shown(menu) {
                const out = [];
                for (let i = 0; i < menu.count; ++i) {
                    const item = menu.itemAt(i);
                    if (item.visible && item.text !== undefined && item.text !== "")
                        out.push(item.text);
                }
                return out;
            }
            function choose(menu, text) {
                for (let i = 0; i < menu.count; ++i) {
                    if (menu.itemAt(i).visible && menu.itemAt(i).text === text) {
                        mouseClick(menu.itemAt(i));
                        tryVerify(() => !menu.visible);
                        return;
                    }
                }
                fail("no visible menu item " + text);
            }

            let menu = open(source);
            const items = shown(menu);
            verify(items.indexOf("Copy Reference") >= 0, items);
            verify(items.indexOf("Paste as Link") >= 0, items);
            verify(items.indexOf("Remove Expression") < 0, items);     // nothing to remove yet
            choose(menu, "Copy Reference");
            compare(Clipboard.paste(), "cube.width");

            menu = open(target);
            choose(menu, "Paste as Link");
            const count = p("ball.count");
            compare(count.expression, "cube.width");
            compare(count.state, Param.Driven);
            compare(count.value, 100);
            p("cube.width").setValue(120);
            compare(count.value, 120);                  // it follows now

            menu = open(target);
            verify(shown(menu).indexOf("Remove Expression") >= 0);
            choose(menu, "Edit Expression");            // editing shows the expression, not the number
            verify(target.control.editing);
            keyClick(Qt.Key_Escape);
            verify(!target.control.editing);
            compare(count.expression, "cube.width");

            menu = open(target);
            choose(menu, "Remove Expression");
            compare(count.expression, "");
            compare(count.state, Param.Normal);
            compare(count.value, 120);                  // the value it had is kept
        }

        // ---- an edit lands on the object it started on

        function test_typed_number_is_applied_before_a_click_elsewhere() {
            const f = make(numberField, { param: p("cube.width") });
            const view = make(viewport);
            view.tapped.connect(() => f.param = p("ball.count"));   // "select another object"
            mouseClick(f, 50, 12);
            type("77");
            mouseClick(view, 100, 50);
            compare(p("cube.width").value, 77);
            compare(p("ball.count").value, 1);
            verify(!f.editing);
            compare(f.param, p("ball.count"));
            compare(root.log, ["start cube.width", "commit cube.width"]);
        }

        function test_refused_text_is_dropped_by_a_click_elsewhere() {
            const f = make(numberField, { param: p("cube.width") });
            const view = make(viewport);
            mouseClick(f, 50, 12);
            type("2*(");
            keyClick(Qt.Key_Return);
            verify(f.editing);                          // kept, with the reason
            mouseClick(view, 100, 50);
            verify(!f.editing);                         // focus is never held hostage
            compare(p("cube.width").value, 100);
        }

        function test_typed_text_is_applied_before_a_click_elsewhere() {
            const f = make(textField, { param: p("cube.name") });
            const view = make(viewport);
            view.tapped.connect(() => f.param = p("ball.count"));
            mouseClick(f, 50, 12);
            keyClick(Qt.Key_A, Qt.ControlModifier);
            type("Box");
            mouseClick(view, 100, 50);
            compare(p("cube.name").value, "Box");
            verify(!f.activeFocus);
        }

        function test_a_parameter_swapped_mid_drag_keeps_the_edit() {
            const f = make(numberField, { param: p("cube.width") });
            mousePress(f, 50, 12);
            for (let x = 51; x <= 73; ++x)
                mouseMove(f, x, 12, -1, Qt.LeftButton);
            compare(p("cube.width").value, 101);
            f.param = p("ball.count");                 // the selection changes mid-drag
            compare(root.log, ["start cube.width", "commit cube.width"]);
            for (let x = 74; x <= 120; ++x)
                mouseMove(f, x, 12, -1, Qt.LeftButton);
            mouseRelease(f, 120, 12);
            compare(p("ball.count").value, 1);          // nothing leaked onto the new one
            compare(p("cube.width").value, 101);
            compare(root.log, ["start cube.width", "commit cube.width"]);

            mousePress(f, 50, 12);                      // the next drag edits the new one
            for (let x = 51; x <= 110; ++x)
                mouseMove(f, x, 12, -1, Qt.LeftButton);
            mouseRelease(f, 110, 12);
            verify(p("ball.count").value > 1, p("ball.count").value);   // an int: a long drag to get past rounding
        }

        function test_field_drag_is_one_transaction() {
            const w = p("cube.width");
            const f = make(numberField, { param: w });
            mousePress(f, 50, 12);
            for (let x = 51; x <= 73; ++x)
                mouseMove(f, x, 12, -1, Qt.LeftButton);
            compare(w.value, 101);
            compare(p("cube.height").value, 50.5);      // followers update during the drag
            keyClick(Qt.Key_Escape);
            compare(w.value, 100);
            mouseRelease(f, 73, 12);
            compare(root.log, ["start cube.width", "cancel cube.width"]);
        }

        function test_driven_field_shows_and_edits_the_expression() {
            const h = p("cube.height");
            const f = make(numberField, { param: h });
            compare(f.displayText, "50");
            verify(!f.canScrub);
            mouseClick(f, 50, 12);
            verify(f.editing);
            keyClick(Qt.Key_End);
            type("+1");                                 // the text was "=width / 2"
            keyClick(Qt.Key_Return);
            compare(h.expression, "width / 2+1");
            compare(h.value, 51);

            mouseClick(f, 50, 12);                      // typing a number unlinks it
            keyClick("a", Qt.ControlModifier);
            type("7");
            keyClick(Qt.Key_Return);
            compare(h.expression, "");
            compare(h.value, 7);
            verify(f.canScrub);

            mouseClick(f, 50, 12);                      // and "=" links it again
            type("=width*2");
            keyClick(Qt.Key_Return);
            compare(h.expression, "width*2");
            compare(h.value, 200);
        }

        function test_invalid_expression_shows_on_the_field() {
            const h = p("cube.height");
            const f = make(numberField, { param: h });
            mouseClick(f, 50, 12);
            keyClick("a", Qt.ControlModifier);
            type("=nope*2");
            keyClick(Qt.Key_Return);
            compare(h.state, Param.Invalid);
            compare(f.value, 50);                       // the last good value
            mouseClick(f, 50, 12);                      // editing shows the failing text
            keyClick(Qt.Key_End);
            keyClick(Qt.Key_Backspace);
            keyClick(Qt.Key_Backspace);
            type("+ width");
            keyClick(Qt.Key_Return);
            compare(h.expression, "nope+ width");
        }

        function test_text_and_bool_controls_on_parameters() {
            const name = p("cube.name");
            const t = make(textField, { param: name });
            compare(t.text, "Cube");
            mouseClick(t, 150, 12);
            type("s");
            keyClick(Qt.Key_Return);
            compare(name.value, "Cubes");
            compare(t.text, "Cubes");
            name.setValue("Ball");
            compare(t.text, "Ball");

            const on = p("ball.on");
            const box = make(checkBox, { y: 40, param: on });
            compare(box.checked, false);
            mouseClick(box);                            // driven: a click changes nothing
            compare(on.value, false);
            p("cube.width").setValue(500);
            compare(box.checked, true);
        }

        // ---- several parameters as one

        function test_merged_parameter() {
            const w = p("cube.width"), n = p("ball.count");
            const both = make(merged, { sources: [w, n] });
            compare(both.state, Param.Mixed);
            compare(both.label, "width");
            const f = make(numberField, { param: both });
            compare(f.displayText, "Mixed");
            mouseClick(f, 50, 12);
            type("9");
            keyClick(Qt.Key_Return);
            compare(w.value, 9);
            compare(n.value, 9);
            compare(both.state, Param.Normal);
            compare(f.displayText, "9");
            compare(root.log, ["start cube.width", "commit cube.width"]);   // one transaction for the lot

            both.sources = [w];                         // a selection of one behaves like the parameter
            compare(both.state, Param.Normal);
            compare(both.reference, "cube.width");
            both.sources = [];
            compare(both.value, undefined);
            compare(f.value, 0);                        // nothing to show: the control's fallback
        }

        function test_merged_text_field_types_over_mixed_values() {
            const a = p("cube.name");
            const b = make(parameter, { name: "ball.name", type: "string", value: "Ball" });
            set.add(b);
            const both = make(merged, { sources: [a, b] });
            const t = make(textField, { param: both });
            compare(both.state, Param.Mixed);
            mouseClick(t, 20, 12);
            compare(t.text, "");                        // typed over from empty
            keyClick(Qt.Key_Escape);
            keyClick(Qt.Key_Tab);                       // leaving without typing changes nothing
            compare(a.value, "Cube");
            compare(b.value, "Ball");
            mouseClick(t, 20, 12);
            type("Same");
            keyClick(Qt.Key_Return);
            compare(a.value, "Same");
            compare(b.value, "Same");
            compare(t.text, "Same");
        }
    }
}
