pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quilt.Controls

// The property grid: PropertyRow, Section and Inspector, built by hand and
// generated from parameter objects.
Item {
    id: root
    width: 360
    height: 500

    property real width_: 10
    property bool flag: false
    property bool on: true

    Component {
        id: grid
        Inspector {
            anchors.fill: parent

            property alias name: nameRow
            property alias first: firstSection
            property alias second: secondSection
            property alias number: numberRow
            property alias check: checkRow
            property alias gate: gate

            PropertyRow {
                id: nameRow
                label: "Name"
                TextField { text: "Cube" }
            }
            Section {
                id: firstSection
                title: "Transform"
                PropertyRow {
                    id: numberRow
                    label: "Width"
                    NumberField { value: root.width_; defaultValue: 10; onEdited: v => root.width_ = v }
                }
                PropertyRow {
                    id: checkRow
                    label: "Visible"
                    CheckBox { checked: root.flag; onEdited: v => root.flag = v }
                }
            }
            Section {
                id: secondSection
                title: "Shadows"
                contentEnabled: root.on
                accessory: Switch { id: gate; checked: root.on; onEdited: v => root.on = v }
                PropertyRow { label: "Blur"; NumberField { value: 4 } }
                PropertyRow { label: "A rather long label that will not fit"; NumberField { value: 4 } }
            }
        }
    }

    // Parameter objects for the generated inspector: anything with `value`
    // and `setValue`.
    component Par: QtObject {
        property string label
        property string group
        property string type
        property string control
        property var value
        property var defaultValue
        property var from
        property var to
        property var suffix
        property var options
        property var hints
        function setValue(v) { value = v; }
    }

    Component { id: par; Par { } }

    // An application's own control for its own type of value.
    Component {
        id: curveEditor
        Rectangle {
            property var param
            implicitWidth: 60
            implicitHeight: 24
            color: "red"
        }
    }

    Component {
        id: generated
        Inspector {
            anchors.fill: parent
            emptyText: "Nothing selected"
        }
    }

    // An item model whose roles describe each value. (A ListModel role has
    // one type, so these are all numbers; a C++ model has no such limit.)
    ListModel {
        id: rows
        ListElement { label: "Gain"; group: ""; value: 0.5 }
        ListElement { label: "Size"; group: "Shape"; value: 12; suffix: " px"; from: 0; to: 100 }
        ListElement { label: "Sides"; group: "Shape"; type: "int"; value: 6 }
    }

    // An item model whose rows each carry a parameter object.
    ListModel { id: objectRows }

    TestCase {
        name: "Inspector"
        when: windowShown

        function make(component, properties) {
            const item = createTemporaryObject(component, root, properties || {});
            verify(item);
            waitForRendering(item);             // rows are laid out on the first frame
            return item;
        }

        function param(properties) { return createTemporaryObject(par, root, properties); }

        function type(text) {
            for (const ch of text)
                keyClick(ch);
        }

        function rowsOf(item, acc) {
            acc = acc || [];
            if (item.label !== undefined && item.control !== undefined && item.visible)
                acc.push(item);
            for (let i = 0; i < item.children.length; ++i)
                rowsOf(item.children[i], acc);
            return acc;
        }

        function sectionsOf(item, acc) {
            acc = acc || [];
            if (item.isQuiltSection === true)
                acc.push(item);
            for (let i = 0; i < item.children.length; ++i)
                sectionsOf(item.children[i], acc);
            return acc;
        }

        // ---- PropertyRow

        function test_values_share_one_left_edge() {
            const g = make(grid);
            const x1 = g.name.control.mapToItem(g, 0, 0).x;
            const x2 = g.number.control.mapToItem(g, 0, 0).x;
            const x3 = g.check.control.mapToItem(g, 0, 0).x;
            compare(x1, x2);
            compare(x2, x3);
            compare(x1, 16 + g.labelWidth);
            compare(g.number.height, 28);       // every row has the one height
            compare(g.check.height, 28);
        }

        function test_label_click_does_the_controls_main_action() {
            const g = make(grid);
            mouseClick(g.number, 40, 14);       // on the label
            verify(g.number.control.editing);
            keyClick(Qt.Key_Escape);
            mouseClick(g.check, 40, 14);
            compare(root.flag, true);
            root.flag = false;
        }

        function test_label_drag_scrubs_the_number() {
            const g = make(grid);
            root.width_ = 10;
            mousePress(g.number, 30, 14);
            for (let x = 31; x <= 53; ++x)
                mouseMove(g.number, x, 14, -1, Qt.LeftButton);
            compare(root.width_, 11);
            mouseRelease(g.number, 53, 14);
            verify(!g.number.control.editing);
            root.width_ = 10;
        }

        function test_modified_dot_resets() {
            const g = make(grid);
            root.width_ = 10;
            verify(!g.number.modified);
            root.width_ = 25;
            verify(g.number.modified);
            mouseClick(g.number, 9, 14);        // the dot, in the gutter
            compare(root.width_, 10);
            verify(!g.number.modified);
        }

        function test_row_menu() {
            const g = make(grid);
            root.width_ = 25;
            mouseClick(g.number, 60, 14, Qt.RightButton);
            const menu = findChild(g.number, "rowMenu");
            verify(menu);
            tryVerify(() => menu.opened);
            const reset = menu.itemAt(0);
            compare(reset.text, "Reset to Default");
            mouseClick(reset);
            tryVerify(() => !menu.visible);
            compare(root.width_, 10);

            // The Menu key opens it for the focused control.
            g.number.control.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Menu);
            tryVerify(() => menu.opened);
            keyClick(Qt.Key_Escape);
            tryVerify(() => !menu.visible);
        }

        function test_long_label_is_cut_and_stacks_when_narrow() {
            const g = make(grid);
            const long_ = rowsOf(g).filter(r => r.label.indexOf("rather long") >= 0)[0];
            verify(findChild(long_, "label").truncated);
            verify(!findChild(g.number, "label").truncated);

            verify(!g.stacked);
            const height = g.number.height;
            root.width = 180;                   // a very narrow panel: label above control
            verify(g.stacked);
            verify(g.number.height > height);
            const c = g.number.control;
            compare(c.mapToItem(g, 0, 0).x, 16);
            root.width = 360;
            verify(!g.stacked);
        }

        function test_wide_panel_caps_the_field_width() {
            const g = make(grid);
            root.width = 900;
            compare(g.number.control.width, g.maximumFieldWidth);
            root.width = 360;
        }

        function test_label_width_can_be_dragged_and_reset() {
            const g = make(grid);
            const auto_ = g.labelWidth;
            const x = 16 + g.labelWidth - 3;
            mousePress(g, x, 100);
            mouseMove(g, x + 20, 100, -1, Qt.LeftButton);
            mouseMove(g, x + 40, 100, -1, Qt.LeftButton);
            mouseRelease(g, x + 40, 100);
            compare(g.labelWidth, auto_ + 40);
            compare(g.number.control.mapToItem(g, 0, 0).x, 16 + auto_ + 40);
            mouseDoubleClickSequence(g, x + 40, 100);
            compare(g.labelWidth, auto_);
        }

        // ---- Section

        function test_whole_header_toggles() {
            const g = make(grid);
            verify(g.first.expanded);
            mouseClick(g.first, 200, 14);       // far from the chevron
            verify(!g.first.expanded);
            tryCompare(g.first, "height", 28 + 13);     // the header and the divider below it
            mouseClick(g.first, 200, 14);
            verify(g.first.expanded);
        }

        function test_section_keys() {
            const g = make(grid);
            findChild(g.first, "header").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Left);
            verify(!g.first.expanded);
            keyClick(Qt.Key_Right);
            verify(g.first.expanded);
            keyClick(Qt.Key_Space);
            verify(!g.first.expanded);
            keyClick(Qt.Key_Return);
            verify(g.first.expanded);
        }

        function test_ctrl_click_toggles_every_section() {
            const g = make(grid);
            mouseClick(g.first, 200, 14, Qt.LeftButton, Qt.ControlModifier);
            verify(!g.first.expanded);
            verify(!g.second.expanded);
            mouseClick(g.second, 200, 14, Qt.LeftButton, Qt.ControlModifier);
            verify(g.first.expanded);
            verify(g.second.expanded);
        }

        function test_collapsed_section_shows_that_something_is_modified() {
            const g = make(grid);
            root.width_ = 10;
            verify(!g.first.hasModified);
            root.width_ = 30;
            verify(g.first.hasModified);
            g.first.expanded = false;
            verify(g.first.hasModified);        // still known while its rows can't be seen
            root.width_ = 10;
            verify(!g.first.hasModified);
        }

        function test_header_switch_gates_the_section_without_toggling_it() {
            const g = make(grid);
            root.on = true;
            mouseClick(g.gate);
            compare(root.on, false);
            verify(g.second.expanded);          // the click was the switch's, not the header's
            const blur = rowsOf(g.second)[0];
            verify(!blur.control.enabled);      // the rows are there but can't be used
            mouseClick(blur, 250, 14);
            verify(!blur.control.editing);
            root.on = true;
        }

        function test_section_remembers_its_state_under_a_key() {
            Qt.application.organization = "QuiltTests";     // Settings needs one
            const first = createTemporaryQmlObject(
                'import Quilt.Controls; Section { key: "tst-inspector/remembered"; title: "A" }', root);
            verify(first.expanded);
            first.expanded = false;
            first.destroy();
            const again = createTemporaryQmlObject(
                'import Quilt.Controls; Section { key: "tst-inspector/remembered"; title: "A" }', root);
            verify(!again.expanded);
            again.expanded = true;              // leave nothing behind for the next run
        }

        // ---- Inspector

        function test_filter_hides_rows_and_opens_sections() {
            const g = make(grid);
            g.first.expanded = false;
            g.filter = "wid";
            compare(rowsOf(g).map(r => r.label), ["Width"]);
            verify(g.first.visible);
            verify(!g.second.visible);          // nothing in it matches
            g.filter = "";
            verify(g.second.visible);
            verify(!g.first.expanded);          // back as the user left it
            compare(rowsOf(g).length >= 3, true);
        }

        function test_search_field_drives_the_filter() {
            const g = make(grid, { searchable: true });
            const field = findChild(g, "filterField");
            verify(field.visible);
            mouseClick(field, 60, 12);
            type("blur");
            compare(g.filter, "blur");
            compare(rowsOf(g).map(r => r.label), ["Blur"]);
            keyClick(Qt.Key_Escape);
            compare(g.filter, "");
        }

        function test_wheel_scrolls_and_a_focused_field_takes_it_instead() {
            const g = make(grid);
            root.height = 120;
            compare(g.contentY, 0);
            mouseWheel(g, 250, 60, 0, -120);
            tryVerify(() => g.contentY > 0);
            const y = g.contentY;
            root.width_ = 10;
            wait(200);                          // let the scroll glide finish
            g.number.control.forceActiveFocus(Qt.TabFocusReason);
            verify(g.number.control.mapToItem(g, 0, 0).y >= 0);     // focus is followed into view
            const settled = g.contentY;
            const p = g.number.control.mapToItem(g, 20, 12);
            mouseWheel(g, p.x, p.y, 0, 120);
            compare(root.width_, 10.1);         // the value stepped…
            wait(150);
            compare(g.contentY, settled);       // …and the panel stayed put
            root.height = 500;
            root.width_ = 10;
        }

        // ---- generated from parameter objects

        function test_generated_rows_and_sections() {
            const a = param({ label: "Name", type: "string", value: "Cube" });
            const b = param({ label: "Width", group: "Size", value: 10, defaultValue: 10, from: 0, to: 100, suffix: " px" });
            const c = param({ label: "Visible", group: "Size", value: true });
            const d = param({ label: "Blend", group: "Look", type: "enum", value: "Normal", options: ["Normal", "Screen"] });
            const g = make(generated, { model: [a, b, c, d] });
            compare(g.count, 4);
            compare(rowsOf(g).map(r => r.label), ["Name", "Width", "Visible", "Blend"]);
            compare(sectionsOf(g).map(s => s.title), ["Size", "Look"]);

            const width = rowsOf(g)[1].control;
            compare(width.value, 10);
            compare(width.suffix, " px");
            verify(width.ranged);
            mouseClick(width, 30, 12);
            type("42");
            keyClick(Qt.Key_Return);
            compare(b.value, 42);
            verify(rowsOf(g)[1].modified);

            const visible = rowsOf(g)[2].control;
            mouseClick(visible);
            compare(c.value, false);

            const blend = rowsOf(g)[3].control;
            compare(blend.count, 2);
            compare(blend.displayText, "Normal");
        }

        function test_generated_rows_are_reused_for_the_same_kind_of_object() {
            const make_ = (name, w) => [param({ label: "Name", type: "string", value: name }),
                                         param({ label: "Width", group: "Size", value: w, from: 0, to: 100 })];
            const one = make_("One", 1), two = make_("Two", 2);
            const g = make(generated, { model: one });
            const row = rowsOf(g)[1];
            const control = row.control;
            const section = sectionsOf(g)[0];
            compare(control.value, 1);
            section.expanded = false;

            g.model = two;                      // another object of the same kind
            compare(sectionsOf(g)[0], section); // the very same section, as the user left it…
            verify(!section.expanded);
            section.expanded = true;
            compare(rowsOf(g)[1], row);
            compare(row.control, control);      // …and the very same control,
            compare(control.value, 2);          // showing the other object's value
            mouseClick(control, 30, 12);
            type("7");
            keyClick(Qt.Key_Return);
            compare(two[1].value, 7);
            compare(one[1].value, 1);           // the edit went to the object now shown
        }

        function test_generated_rows_follow_parameters_that_fill_in_later() {
            const late = param({});
            const g = make(generated, { model: [late] });
            compare(rowsOf(g).length, 1);
            late.label = "Fill";
            late.group = "Look";
            late.type = "color";
            late.value = Qt.color("#ff0000");
            compare(sectionsOf(g).map(s => s.title), ["Look"]);
            const row = rowsOf(g)[0];
            compare(row.label, "Fill");
            verify(row.control.pickerOpen !== undefined);       // it became a ColorField
            late.suffix = "!";
            late.from = 2;                      // hints that arrive later are applied too
        }

        function test_generated_hints_object_and_custom_delegate() {
            const hinted = param({ label: "Angle", value: 90, hints: { from: 0, to: 360, suffix: "°", wrap: true } });
            const custom = param({ label: "Curve", type: "curve", value: 3 });
            const g = make(generated, { model: [hinted, custom] });
            g.delegates = { curve: curveEditor };
            const angle = rowsOf(g)[0].control;
            compare(angle.to, 360);
            compare(angle.suffix, "°");
            verify(angle.wrap);
            const mine = rowsOf(g)[1].control;
            compare(mine.color, Qt.color("red"));
            compare(mine.param, custom);
        }

        function test_generated_empty_text() {
            const g = make(generated, { model: [] });
            const empty = findChild(g, "emptyText");
            verify(empty.visible);
            compare(empty.text, "Nothing selected");
            g.model = [param({ label: "A", value: 1 })];
            tryVerify(() => !empty.visible);
            g.filter = "zzz";
            tryVerify(() => empty.visible);
            verify(empty.text.indexOf("zzz") >= 0);
        }

        function test_generated_from_an_item_model() {
            const g = make(generated, { model: rows });
            compare(g.count, 3);
            compare(rowsOf(g).map(r => r.label), ["Gain", "Size", "Sides"]);
            compare(sectionsOf(g).map(s => s.title), ["Shape"]);
            const size = rowsOf(g)[1].control;
            compare(size.value, 12);
            compare(size.suffix, " px");
            verify(size.ranged);
            verify(rowsOf(g)[2].control.integer);
            mouseClick(size, 30, 12);
            type("30");
            keyClick(Qt.Key_Return);
            compare(rows.get(1).value, 30);     // written back through the model
            rows.setProperty(1, "value", 31);   // and a change in the model shows
            compare(size.value, 31);

            rows.append({ label: "Depth", group: "Shape", value: 2 });
            tryCompare(g, "count", 4);
            tryVerify(() => rowsOf(g).length === 4);
            rows.remove(3);
            tryCompare(g, "count", 3);
        }

        function test_generated_from_an_item_model_of_parameter_objects() {
            const a = param({ label: "Name", type: "string", value: "Cube" });
            const b = param({ label: "Visible", type: "bool", value: true });
            objectRows.clear();
            objectRows.append({ parameter: a });
            objectRows.append({ parameter: b });
            const g = make(generated, { model: objectRows });
            compare(rowsOf(g).map(r => r.label), ["Name", "Visible"]);
            mouseClick(rowsOf(g)[1].control);
            compare(b.value, false);
        }
    }
}
