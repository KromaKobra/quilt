import QtQuick
import QtTest
import Quilt.Controls

// VectorField, ColorField (with its picker) and DateField.
Item {
    id: root
    width: 520
    height: 520

    property vector3d position: Qt.vector3d(1, 2, 3)
    property var pair: [10, 20]
    property size size: Qt.size(40, 30)
    property color fill: "#4c8dff"
    property date due: new Date(2026, 10, 12, 14, 30, 0)
    property var log: []

    Component {
        id: vector
        VectorField {
            width: 300
            value: root.position
            onEditStarted: root.log.push("start")
            onEdited: v => { root.log.push("edit"); root.position = v; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }
    Component { id: pairField; VectorField { width: 300; value: root.pair; onEdited: v => root.pair = v } }
    Component { id: sizeField; VectorField { width: 300; value: root.size; onEdited: v => root.size = v } }

    Component {
        id: color
        ColorField {
            width: 200
            value: root.fill
            onEditStarted: root.log.push("start")
            onEdited: c => { root.log.push("edit"); root.fill = c; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }

    Component {
        id: date
        DateField {
            value: root.due
            onEditStarted: root.log.push("start")
            onEdited: d => { root.log.push("edit"); root.due = d; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }

    TestCase {
        name: "CompoundFields"
        when: windowShown

        function init() {
            root.position = Qt.vector3d(1, 2, 3);
            root.pair = [10, 20];
            root.size = Qt.size(40, 30);
            root.fill = "#4c8dff";
            root.due = new Date(2026, 10, 12, 14, 30, 0);
            root.log = [];
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

        function signals() { return root.log.filter(x => x !== "edit"); }

        function hex(c) { return c.toString().toLowerCase(); }

        // ---- VectorField

        function test_vector_edits_one_component_and_keeps_the_type() {
            const f = make(vector);
            compare(f.count, 3);
            mouseClick(f, 150, 12);             // the middle component
            type("7");
            keyClick(Qt.Key_Return);
            compare(root.position, Qt.vector3d(1, 7, 3));
            compare(signals(), ["start", "commit"]);
        }

        function test_vector_types() {
            const a = make(pairField);
            compare(a.count, 2);
            mouseClick(a, 40, 12);
            type("5");
            keyClick(Qt.Key_Return);
            compare(root.pair.length, 2);
            compare(root.pair[0], 5);
            compare(root.pair[1], 20);

            const s = make(sizeField, { y: 40 });
            compare(s.count, 2);
            mouseClick(s, 200, 52 - 40);
            type("99");
            keyClick(Qt.Key_Return);
            compare(root.size, Qt.size(40, 99));
        }

        function test_vector_drag_is_one_transaction() {
            const f = make(vector);
            mousePress(f, 40, 12);
            for (let x = 41; x <= 63; ++x)
                mouseMove(f, x, 12, -1, Qt.LeftButton);
            compare(root.position, Qt.vector3d(2, 2, 3));   // 20 px at 2 px per 0.1
            mouseRelease(f, 63, 12);
            compare(signals(), ["start", "commit"]);
        }

        function test_vector_typed_list_fills_all() {
            const f = make(vector);
            mouseClick(f, 40, 12);
            type("4, 5, 6");
            keyClick(Qt.Key_Return);
            compare(root.position, Qt.vector3d(4, 5, 6));

            mouseClick(f, 150, 12);             // a shorter list starts at the component it was typed in
            type("8 9");
            keyClick(Qt.Key_Return);
            compare(root.position, Qt.vector3d(4, 8, 9));

            f.pasteText("1, 2, 3");
            compare(root.position, Qt.vector3d(1, 2, 3));
            compare(f.copyText(), "1, 2, 3");
        }

        function test_vector_linked_keeps_proportions() {
            const f = make(vector, { linkable: true, linked: true });
            mouseClick(f, 30, 12);
            type("2");
            keyClick(Qt.Key_Return);
            compare(root.position, Qt.vector3d(2, 4, 6));
        }

        function test_vector_tab_moves_through_components() {
            const f = make(vector);
            mouseClick(f, 30, 12);
            type("9");
            keyClick(Qt.Key_Tab);
            compare(root.position.x, 9);
            type("8");
            keyClick(Qt.Key_Tab);
            compare(root.position.y, 8);
            type("7");
            keyClick(Qt.Key_Return);
            compare(root.position, Qt.vector3d(9, 8, 7));
        }

        function test_vector_stacks_when_narrow() {
            const f = make(vector, { width: 120 });
            verify(f.implicitHeight > 60);
            f.width = 300;
            compare(f.implicitHeight, 24);
        }

        function test_vector_modified_reset_and_states() {
            const f = make(vector, { defaultValue: Qt.vector3d(0, 0, 0) });
            verify(f.modified);
            f.reset();
            compare(root.position, Qt.vector3d(0, 0, 0));
            verify(!f.modified);

            const mixed = make(vector, { y: 40, paramState: Param.Mixed });
            mouseClick(mixed, 30, 52 - 40);
            type("5");
            keyClick(Qt.Key_Return);
            compare(root.position.x, 5);

            const readOnly = make(vector, { y: 80, readOnly: true });
            mouseClick(readOnly, 30, 12);
            type("6");
            compare(root.position.x, 5);
        }

        // ---- ColorField

        function test_color_hex_entry() {
            const f = make(color);
            const cases = [["#ff0000", "#ff0000"], ["0f0", "#00ff00"], ["rgb(0, 0, 255)", "#0000ff"], ["white", "#ffffff"]];
            for (const c of cases) {
                f.pasteText(c[0]);
                compare(hex(root.fill), c[1], c[0]);
            }
            f.pasteText("not a colour");
            compare(hex(root.fill), "#ffffff");
            f.pasteText("#11223380");           // with opacity
            fuzzyCompare(root.fill.a, 128 / 255, 1e-6);
            compare(f.copyText(), "#11223380");
        }

        function test_color_typing_keeps_the_opacity() {
            const f = make(color);
            root.fill = Qt.rgba(1, 0, 0, 0.5);
            mouseClick(f, 60, 12);              // the hex field
            keyClick("a", Qt.ControlModifier);
            type("00ff00");
            keyClick(Qt.Key_Return);
            compare(root.fill.g, 1);
            compare(root.fill.r, 0);
            compare(root.fill.a, 0.5);
            compare(signals(), ["start", "commit"]);
        }

        function test_color_opacity_scrubs() {
            const f = make(color);
            mousePress(f, f.width - 20, 12);
            for (let x = f.width - 21; x >= f.width - 60; --x)
                mouseMove(f, x, 12, -1, Qt.LeftButton);
            verify(root.fill.a < 1);
            compare(root.fill.b, 1);
            mouseRelease(f, f.width - 60, 12);
            compare(signals(), ["start", "commit"]);
        }

        function test_color_without_alpha() {
            const f = make(color, { alpha: false });
            f.pasteText("#11223380");
            compare(root.fill.a, 1);
            compare(f.copyText(), "#112233");
        }

        function openPicker(f) {
            mouseClick(f, 12, 12);              // the swatch
            verify(f.pickerOpen);
            const picker = f._picker;
            tryVerify(() => picker.opened);
            return picker;
        }

        function test_picker_one_visit_is_one_edit() {
            const f = make(color);
            const picker = openPicker(f);
            const square = picker.contentItem.children[0];
            mousePress(square, 10, 10);
            mouseMove(square, 60, 40, -1, Qt.LeftButton);
            mouseMove(square, 100, 60, -1, Qt.LeftButton);
            mouseRelease(square, 100, 60);
            mouseClick(square, 30, 100);        // a second gesture in the same visit
            verify(hex(root.fill) !== "#4c8dff");
            compare(signals(), ["start"]);
            keyClick(Qt.Key_Return);            // Enter keeps the colour
            tryVerify(() => !f.pickerOpen);
            compare(signals(), ["start", "commit"]);
            verify(hex(root.fill) !== "#4c8dff");
        }

        function test_picker_escape_restores() {
            const f = make(color);
            const picker = openPicker(f);
            const square = picker.contentItem.children[0];
            mouseClick(square, 100, 60);
            verify(hex(root.fill) !== "#4c8dff");
            keyClick(Qt.Key_Escape);
            tryVerify(() => !f.pickerOpen);
            compare(hex(root.fill), "#4c8dff");
            compare(signals(), ["start", "cancel"]);
        }

        function test_picker_click_outside_keeps() {
            const f = make(color);
            const picker = openPicker(f);
            mouseClick(picker.contentItem.children[0], 100, 60);
            const changed = hex(root.fill);
            mouseClick(root, 500, 500);
            tryVerify(() => !f.pickerOpen);
            compare(hex(root.fill), changed);
            compare(signals(), ["start", "commit"]);
        }

        function test_picker_opening_and_closing_untouched_is_not_an_edit() {
            const f = make(color);
            openPicker(f);
            keyClick(Qt.Key_Return);
            tryVerify(() => !f.pickerOpen);
            compare(root.log, []);
        }

        function test_picker_remembers_hue_and_saturation() {
            const f = make(color);
            const picker = openPicker(f);
            const hue = picker.h;
            verify(hue > 0.5);                  // a blue
            const square = picker.contentItem.children[0];
            mousePress(square, 100, 100);
            mouseMove(square, 100, 120, -1, Qt.LeftButton);
            mouseMove(square, 100, 200, -1, Qt.LeftButton);     // past the bottom edge: value 0, black
            compare(hex(root.fill), "#000000");
            fuzzyCompare(picker.h, hue, 1e-6);
            fuzzyCompare(picker.s, 100 / square.width, 1e-6);
            mouseMove(square, 100, 60, -1, Qt.LeftButton);      // and back up, in the same drag
            mouseMove(square, 100, 20, -1, Qt.LeftButton);
            mouseRelease(square, 100, 20);
            fuzzyCompare(root.fill.hsvHue, hue, 0.01);  // still blue, not red
            keyClick(Qt.Key_Escape);
            tryVerify(() => !f.pickerOpen);
        }

        function test_color_states() {
            const driven = make(color, { paramState: Param.Driven });
            mouseClick(driven, 12, 12);
            verify(!driven.pickerOpen);
            const readOnly = make(color, { y: 40, readOnly: true });
            mouseClick(readOnly, 12, 12);
            verify(!readOnly.pickerOpen);
            readOnly.pasteText("#ff0000");
            compare(hex(root.fill), "#4c8dff");

            const mixed = make(color, { y: 80, paramState: Param.Mixed });
            compare(mixed.copyText(), "");
            mixed.pasteText("#ff0000");
            compare(hex(root.fill), "#ff0000");
        }

        // ---- DateField

        function test_date_displays_segments() {
            const f = make(date);
            compare(f.displayText, "2026-11-12");
            f.mode = "datetime";
            compare(f.displayText, "2026-11-12  14:30");
            f.seconds = true;
            compare(f.displayText, "2026-11-12  14:30:00");
            f.mode = "time";
            compare(f.displayText, "14:30:00");
        }

        function test_date_keys_step_and_carry() {
            const f = make(date);
            f.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Right);             // the day
            for (let i = 0; i < 19; ++i)
                keyClick(Qt.Key_Up);            // 12 + 19 = Dec 1
            compare(f.displayText, "2026-12-01");
            keyClick(Qt.Key_Left);              // the month
            keyClick(Qt.Key_Up);
            compare(f.displayText, "2027-01-01");
            compare(signals(), ["start"]);      // one run of steps
            keyClick(Qt.Key_Escape);
            compare(f.displayText, "2026-11-12");
            compare(signals(), ["start", "cancel"]);
        }

        function test_date_day_stays_within_the_month() {
            const f = make(date);
            root.due = new Date(2026, 0, 31);
            f.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Right);             // the month
            keyClick(Qt.Key_Up);
            compare(f.displayText, "2026-02-28");
        }

        function test_date_typing_digits_advances() {
            const f = make(date);
            f.forceActiveFocus(Qt.TabFocusReason);
            f.activate();                       // the first segment
            type("2031");                       // full: moves on to the month
            type("3");                          // 3x can't be a month: applies and moves on
            type("07");
            compare(f.displayText, "2031-03-07");
            verify(root.due.getFullYear() === 2031 && root.due.getMonth() === 2 && root.due.getDate() === 7);
        }

        function test_date_drag_scrubs_a_segment() {
            const f = make(date, { mode: "time" });
            const hours = f.contentItem.children[1].children[0].children[1];
            mousePress(hours, 4, 6);
            for (let x = 5; x <= 4 + 3 + 18; ++x)
                mouseMove(hours, x, 6, -1, Qt.LeftButton);
            compare(root.due.getHours(), 17);   // 6 px a step
            mouseRelease(hours, 25, 6);
            compare(signals(), ["start", "commit"]);
        }

        function test_date_paste_and_limits() {
            const f = make(date, { mode: "datetime" });
            f.pasteText("2030-02-03 04:05");
            compare(f.displayText, "2030-02-03  04:05");
            f.pasteText("gibberish");
            compare(f.displayText, "2030-02-03  04:05");
            f.pasteText("9:15");                // a time alone keeps the date
            compare(f.displayText, "2030-02-03  09:15");

            f.minimum = new Date(2030, 0, 1);
            f.maximum = new Date(2030, 11, 31);
            f.pasteText("2040-01-01");
            compare(f.displayText.slice(0, 10), "2030-12-31");
        }

        function test_date_calendar() {
            const f = make(date);
            f.openCalendar();
            verify(f.calendarOpen);
            const calendar = f._calendar;
            tryVerify(() => calendar.opened);
            const grid = calendar.contentItem.children[2];
            // November 2026 starts on a Sunday; find the cell for the 20th by its text.
            let cell = null;
            for (let i = 0; i < grid.children.length; ++i) {
                const c = grid.children[i];
                if (c.day !== undefined && c.inMonth && c.day.getDate() === 20)
                    cell = c;
            }
            verify(cell);
            mouseClick(cell);
            tryVerify(() => !f.calendarOpen);
            compare(f.displayText, "2026-11-20");
            compare(root.due.getHours(), 14);   // the time of day is kept
            compare(signals(), ["start", "commit"]);
        }

        function test_date_states() {
            const readOnly = make(date, { readOnly: true });
            readOnly.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            type("1999");
            readOnly.openCalendar();
            verify(!readOnly.calendarOpen);
            compare(root.due.getFullYear(), 2026);
            compare(root.log, []);
        }
    }
}
