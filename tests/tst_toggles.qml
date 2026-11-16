import QtQuick
import QtTest
import Quilt.Controls

// CheckBox, Switch and SegmentedButton.
Item {
    id: root
    width: 420
    height: 300

    property bool flag: false
    property var choice: "Center"
    property var styles: ["bold"]
    property var log: []

    Component {
        id: boundCheck
        CheckBox {
            text: "Bound"
            checked: root.flag
            onEditStarted: root.log.push("start")
            onEdited: v => { root.log.push(v); root.flag = v; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }
    Component { id: refusedCheck; CheckBox { text: "Refused"; checked: root.flag } }
    Component { id: freeCheck; CheckBox { text: "Free" } }

    Component {
        id: boundSwitch
        Switch {
            checked: root.flag
            onEditStarted: root.log.push("start")
            onEdited: v => { root.log.push(v); root.flag = v; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }
    Component { id: refusedSwitch; Switch { checked: root.flag } }
    Component { id: freeSwitch; Switch { } }

    Component {
        id: segmented
        SegmentedButton {
            width: 240
            model: ["Left", "Center", "Right"]
            value: root.choice
            onEditStarted: root.log.push("start")
            onEdited: v => { root.log.push(v); root.choice = v; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }
    Component {
        id: toggles
        SegmentedButton {
            width: 120
            model: [{ text: "B", value: "bold" }, { text: "I", value: "italic" }, { text: "U", value: "underline", enabled: false }]
            exclusive: false
            value: root.styles
            onEdited: v => root.styles = v
        }
    }

    TestCase {
        name: "Toggles"
        when: windowShown

        function init() {
            root.flag = false;
            root.choice = "Center";
            root.styles = ["bold"];
            root.log = [];
        }

        function make(component, properties) {
            const item = createTemporaryObject(component, root, properties || {});
            verify(item);
            return item;
        }

        // ---- CheckBox

        function test_checkbox_click_is_one_transaction() {
            const box = make(boundCheck);
            mouseClick(box);
            compare(root.flag, true);
            compare(box.checked, true);
            compare(root.log, ["start", true, "commit"]);
            mouseClick(box);
            compare(root.flag, false);
        }

        function test_checkbox_follows_the_application() {
            const box = make(boundCheck);
            mouseClick(box);
            root.flag = false;                  // the binding survived the click
            compare(box.checked, false);
        }

        function test_checkbox_refused_edit_snaps_back() {
            const box = make(refusedCheck);
            mouseClick(box);
            compare(box.checked, false);
            root.flag = true;
            compare(box.checked, true);
        }

        function test_checkbox_without_a_handler_works_like_a_stock_one() {
            const box = make(freeCheck);
            mouseClick(box);
            compare(box.checked, true);
            mouseClick(box);
            compare(box.checked, false);
        }

        function test_checkbox_space_toggles() {
            const box = make(boundCheck);
            box.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            compare(root.flag, true);
        }

        function test_checkbox_mixed_turns_on_and_never_comes_back() {
            const box = make(boundCheck, { paramState: Param.Mixed });
            mouseClick(box);
            compare(root.flag, true);           // a click on mixed turns it on for all
            box.paramState = Param.Normal;
            mouseClick(box);
            compare(root.flag, false);

            root.flag = true;
            box.paramState = Param.Mixed;       // mixed and on underneath: still "on for all"
            mouseClick(box);
            compare(root.flag, true);
        }

        function test_checkbox_driven_and_read_only_ignore_clicks() {
            const driven = make(boundCheck, { paramState: Param.Driven });
            mouseClick(driven);
            const readOnly = make(boundCheck, { y: 30, readOnly: true });
            mouseClick(readOnly);
            const disabled = make(boundCheck, { y: 60, enabled: false });
            mouseClick(disabled);
            compare(root.flag, false);
            compare(root.log, []);
        }

        function test_checkbox_modified_reset_and_text() {
            const box = make(boundCheck, { defaultValue: true });
            verify(box.modified);
            box.reset();
            compare(root.flag, true);
            verify(!box.modified);
            compare(box.copyText(), "true");
            box.pasteText("false");
            compare(root.flag, false);
            box.activate();                     // what clicking the row label does
            compare(root.flag, true);
        }

        // ---- Switch

        function test_switch_click() {
            const sw = make(boundSwitch);
            mouseClick(sw);
            compare(root.flag, true);
            compare(sw.checked, true);
            compare(root.log, ["start", true, "commit"]);
            root.flag = false;
            compare(sw.checked, false);
        }

        function test_switch_refused_edit_snaps_back() {
            const sw = make(refusedSwitch);
            mouseClick(sw);
            compare(sw.checked, false);
            compare(sw.visualPosition, 0);
            root.flag = true;
            compare(sw.checked, true);
        }

        function test_switch_without_a_handler() {
            const sw = make(freeSwitch);
            mouseClick(sw);
            compare(sw.checked, true);
            mouseClick(sw);
            compare(sw.checked, false);
        }

        function test_switch_drag_decides_on_release() {
            const sw = make(boundSwitch);
            mousePress(sw, 4, 12);
            mouseMove(sw, 14, 12, -1, Qt.LeftButton);
            mouseMove(sw, 40, 12, -1, Qt.LeftButton);
            compare(root.flag, false);          // nothing until release
            mouseRelease(sw, 40, 12);
            compare(root.flag, true);
            compare(root.log, ["start", true, "commit"]);

            mousePress(sw, 22, 12);             // dragged out and back: no change
            mouseMove(sw, 10, 12, -1, Qt.LeftButton);
            mouseMove(sw, 40, 12, -1, Qt.LeftButton);
            mouseRelease(sw, 40, 12);
            compare(root.flag, true);
        }

        function test_switch_space_and_states() {
            const sw = make(boundSwitch);
            sw.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            compare(root.flag, true);

            const readOnly = make(boundSwitch, { y: 30, readOnly: true });
            mouseClick(readOnly);
            compare(root.flag, true);
            compare(readOnly.checked, true);
            const driven = make(boundSwitch, { y: 60, paramState: Param.Driven });
            mouseClick(driven);
            compare(root.flag, true);
            compare(driven.checked, true);
        }

        // ---- SegmentedButton

        function test_segmented_click() {
            const seg = make(segmented);
            compare(seg.currentIndex, 1);
            mouseClick(seg, 200, 12);
            compare(root.choice, "Right");
            compare(seg.currentIndex, 2);
            compare(root.log, ["start", "Right", "commit"]);
            mouseClick(seg, 200, 12);           // already chosen: not an edit
            compare(root.log.length, 3);
        }

        function test_segmented_keys() {
            const seg = make(segmented);
            seg.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Left);
            compare(root.choice, "Left");
            keyClick(Qt.Key_Left);              // stops at the end
            compare(root.choice, "Left");
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Right);
            compare(root.choice, "Right");
        }

        function test_segmented_refused_and_mixed() {
            const seg = make(segmented);
            seg.edited.disconnect(seg.edited);  // no-op; the handler below refuses instead
            const refused = createTemporaryQmlObject(
                'import Quilt.Controls; SegmentedButton { width: 240; y: 40; model: ["A", "B"]; value: "A" }', root);
            refused.value = Qt.binding(() => root.flag ? "B" : "A");
            mouseClick(refused, 200, 12);
            compare(refused.value, "A");
            compare(refused.currentIndex, 0);

            seg.paramState = Param.Mixed;
            compare(seg.currentIndex, -1);      // mixed: nothing selected
            mouseClick(seg, 40, 12);
            compare(root.choice, "Left");
        }

        function test_segmented_object_options_and_values() {
            const seg = make(segmented, { model: [{ text: "Low", value: 1 }, { text: "High", value: 3 }], value: 3 });
            compare(seg.currentIndex, 1);
            let got = null;
            seg.edited.connect(v => got = v);
            mouseClick(seg, 40, 12);
            compare(got, 1);
        }

        function test_independent_toggles() {
            const seg = make(toggles);
            verify(seg.isOn(0));
            verify(!seg.isOn(1));
            mouseClick(seg, 60, 12);            // italic on
            compare(root.styles, ["bold", "italic"]);
            mouseClick(seg, 20, 12);            // bold off
            compare(root.styles, ["italic"]);
            mouseClick(seg, 20, 12);            // bold on again: kept in option order
            compare(root.styles, ["bold", "italic"]);
            mouseClick(seg, 100, 12);           // a disabled option
            compare(root.styles, ["bold", "italic"]);

            seg.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Left);
            keyClick(Qt.Key_Left);
            keyClick(Qt.Key_Space);             // toggles the option under the keyboard cursor
            compare(root.styles, ["italic"]);
        }

        function test_segmented_read_only_and_driven() {
            const seg = make(segmented, { readOnly: true });
            mouseClick(seg, 200, 12);
            seg.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Right);
            compare(root.choice, "Center");
            const driven = make(segmented, { y: 40, paramState: Param.Driven });
            mouseClick(driven, 200, 12);
            compare(root.choice, "Center");
        }
    }
}
