import QtQuick
import QtTest
import Quilt.Controls

// ComboBox: choosing by value, the popup, keys, and the parameter states.
Item {
    id: root
    width: 420
    height: 400

    property string blend: "Normal"
    property int quality: 2
    property var log: []

    readonly property var blends: ["Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten"]

    Component {
        id: bound
        ComboBox {
            width: 160
            model: root.blends
            value: root.blend
            onEditStarted: root.log.push("start")
            onEdited: v => { root.log.push(v); root.blend = v; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }
    Component {
        id: valued
        ComboBox {
            width: 160
            model: [{ text: "Low", value: 1 }, { text: "Medium", value: 2 }, { text: "High", value: 3 }]
            value: root.quality
            onEdited: v => root.quality = v
        }
    }
    Component { id: refused; ComboBox { width: 160; model: root.blends; value: root.blend } }
    Component { id: stock; ComboBox { width: 160; model: root.blends } }

    TestCase {
        name: "ComboBox"
        when: windowShown

        function init() {
            root.blend = "Normal";
            root.quality = 2;
            root.log = [];
        }

        function make(component, properties) {
            const item = createTemporaryObject(component, root, properties || {});
            verify(item);
            return item;
        }

        // Clicks the option at `index` of an open popup.
        function pick(combo, index) {
            tryVerify(() => combo.popup.opened);
            const list = combo.popup.contentItem;
            const option = list.itemAtIndex(index);
            verify(option, "option " + index);
            mouseClick(option);
            tryVerify(() => !combo.popup.visible);
        }

        function test_shows_the_option_for_the_value() {
            const combo = make(bound);
            compare(combo.currentIndex, 0);
            compare(combo.displayText, "Normal");
            root.blend = "Screen";
            compare(combo.currentIndex, 2);
            compare(combo.displayText, "Screen");
        }

        function test_click_opens_and_a_choice_is_one_transaction() {
            const combo = make(bound);
            mouseClick(combo);
            pick(combo, 3);
            compare(root.blend, "Overlay");
            compare(combo.currentIndex, 3);
            compare(root.log, ["start", "Overlay", "commit"]);
        }

        function test_escape_closes_without_a_change() {
            const combo = make(bound);
            mouseClick(combo);
            tryVerify(() => combo.popup.opened);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Escape);
            tryVerify(() => !combo.popup.visible);
            compare(root.blend, "Normal");
            compare(root.log, []);
        }

        function test_keys_while_closed() {
            const combo = make(bound);
            combo.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Down);
            compare(root.blend, "Multiply");
            keyClick(Qt.Key_Down);
            compare(root.blend, "Screen");
            keyClick(Qt.Key_Up);
            compare(root.blend, "Multiply");
            keyClick("d");                      // a letter jumps to a match
            compare(root.blend, "Darken");
        }

        function test_keys_while_open() {
            const combo = make(bound);
            combo.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            tryVerify(() => combo.popup.opened);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Down);
            compare(root.blend, "Normal");      // moving the highlight changes nothing
            keyClick(Qt.Key_Return);
            tryVerify(() => !combo.popup.visible);
            compare(root.blend, "Screen");
        }

        function test_values_from_object_options() {
            const combo = make(valued);
            compare(combo.displayText, "Medium");
            mouseClick(combo);
            pick(combo, 2);
            compare(root.quality, 3);
            compare(combo.displayText, "High");
            root.quality = 1;
            compare(combo.displayText, "Low");
        }

        function test_refused_choice_snaps_back() {
            const combo = make(refused);
            mouseClick(combo);
            pick(combo, 4);
            compare(combo.currentIndex, 0);
            compare(combo.displayText, "Normal");
            compare(combo.value, "Normal");
            root.blend = "Lighten";
            compare(combo.displayText, "Lighten");
        }

        function test_works_by_index_like_a_stock_one() {
            const combo = make(stock);
            compare(combo.currentIndex, 0);
            mouseClick(combo);
            pick(combo, 2);
            compare(combo.currentIndex, 2);
            compare(combo.currentText, "Screen");
        }

        function test_wheel_needs_focus() {
            const combo = make(bound);
            mouseWheel(combo, 20, 12, 0, -120);
            compare(root.blend, "Normal");
            combo.forceActiveFocus(Qt.TabFocusReason);
            mouseWheel(combo, 20, 12, 0, -120);
            compare(root.blend, "Multiply");
        }

        function test_mixed() {
            const combo = make(bound, { paramState: Param.Mixed });
            compare(combo.currentIndex, -1);
            compare(combo.contentItem.text, "Mixed");
            mouseClick(combo);
            pick(combo, 1);
            compare(root.blend, "Multiply");
        }

        function test_driven_and_read_only_do_not_open() {
            const driven = make(bound, { paramState: Param.Driven });
            mouseClick(driven);
            wait(50);
            verify(!driven.popup.visible);
            driven.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Down);
            compare(root.blend, "Normal");

            const readOnly = make(bound, { y: 40, readOnly: true });
            mouseClick(readOnly);
            wait(50);
            verify(!readOnly.popup.visible);
            compare(root.log, []);
        }

        function test_popup_fits_its_longest_option() {
            const combo = make(bound, { width: 60, model: ["A", "A considerably longer option"] });
            mouseClick(combo);
            tryVerify(() => combo.popup.opened);
            verify(combo.popup.width > 150);
            const option = combo.popup.contentItem.itemAtIndex(1);
            verify(!option.contentItem.truncated);
            keyClick(Qt.Key_Escape);
        }

        function test_modified_reset_and_text() {
            const combo = make(bound, { defaultValue: "Screen" });
            verify(combo.modified);
            combo.reset();
            compare(root.blend, "Screen");
            verify(!combo.modified);
            compare(combo.copyText(), "Screen");
            combo.pasteText("Darken");
            compare(root.blend, "Darken");
            combo.pasteText("No such option");
            compare(root.blend, "Darken");
        }
    }
}
