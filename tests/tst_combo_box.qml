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
    Component {
        id: rich
        ComboBox {
            width: 160
            model: [{ text: "Red", value: "r", color: "#f0616d" }, { text: "Green", value: "g", color: "#4fbf7b" },
                    { separator: true },
                    { text: "Locked", value: "l", icon: "lock", enabled: false }, { text: "Custom…", value: "c", icon: "settings" }]
            value: root.blend
            onEdited: v => root.blend = v
        }
    }
    Component {
        id: fonts
        ComboBox {
            width: 160
            model: ["Arial", "Baskerville", "Bodoni", "Courier", "Didot", "Futura", "Garamond", "Georgia", "Gill Sans",
                    "Helvetica", "Optima", "Palatino", "Rockwell", "Times", "Univers", "Verdana"]
            value: root.blend
            onEdited: v => root.blend = v
        }
    }

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

        function find(item, predicate) {
            if (predicate(item))
                return item;
            for (let i = 0; i < item.children.length; ++i) {
                const found = find(item.children[i], predicate);
                if (found)
                    return found;
            }
            return null;
        }

        function options(combo) { return find(combo.popup.contentItem, i => i.objectName === "options"); }
        function shownOptions(combo) {
            const out = [];
            for (let i = 0; i < combo.count; ++i) {
                const option = options(combo).itemAtIndex(i);
                if (option && option.visible && !option.separator)
                    out.push(option.text);
            }
            return out;
        }

        // Clicks the option at `index` of an open popup.
        function pick(combo, index) {
            tryVerify(() => combo.popup.opened);
            const option = options(combo).itemAtIndex(index);
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
            compare(find(combo.contentItem, i => i.objectName === "shownText").text, "Mixed");
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
            const option = options(combo).itemAtIndex(1);
            verify(!find(option.contentItem, i => i.objectName === "optionText").truncated);
            keyClick(Qt.Key_Escape);
        }

        function test_a_resting_pointer_does_not_steal_the_highlight() {
            const combo = make(bound);
            mouseMove(combo, 40, 70);           // where the list will open: over "Multiply"
            combo.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            tryVerify(() => combo.popup.opened);
            wait(50);
            compare(combo._hi, 0);              // still on the current option
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            tryVerify(() => !combo.popup.visible);
            compare(root.blend, "Multiply");
        }

        function test_space_chooses_the_highlighted_option() {
            const combo = make(bound);
            combo.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            tryVerify(() => combo.popup.opened);
            keyClick(Qt.Key_End);
            keyClick(Qt.Key_Up);
            keyClick(Qt.Key_Space);
            tryVerify(() => !combo.popup.visible);
            compare(root.blend, "Darken");
            compare(root.log, ["start", "Darken", "commit"]);
        }

        function test_hover_highlights_and_nothing_more() {
            const combo = make(bound);
            mouseClick(combo);
            tryVerify(() => combo.popup.opened);
            const option = options(combo).itemAtIndex(2);
            mouseMove(option, 10, 5);
            mouseMove(option, 12, 6);
            tryVerify(() => option.highlighted);
            compare(root.blend, "Normal");
            compare(root.log, []);
            keyClick(Qt.Key_Return);            // Enter takes what is highlighted
            tryVerify(() => !combo.popup.visible);
            compare(root.blend, "Screen");
        }

        // ---- options with marks, separators and disabled entries

        function test_separators_and_disabled_options_are_skipped() {
            root.blend = "g";
            const combo = make(rich);
            compare(combo.displayText, "Green");
            combo.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Down);              // over the separator and the disabled option
            compare(root.blend, "c");
            keyClick(Qt.Key_Up);
            compare(root.blend, "g");

            mouseClick(combo);
            tryVerify(() => combo.popup.opened);
            const list = options(combo);
            verify(list.itemAtIndex(2).separator);
            verify(list.itemAtIndex(2).height < 12);
            verify(!list.itemAtIndex(3).enabled);
            mouseClick(list.itemAtIndex(3));    // disabled: nothing happens, the list stays
            wait(50);
            verify(combo.popup.visible);
            compare(root.blend, "g");
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            tryVerify(() => !combo.popup.visible);
            compare(root.blend, "c");
        }

        function test_options_show_their_chip_or_icon() {
            root.blend = "r";
            const combo = make(rich);
            const mark = find(combo.contentItem, i => i.chip !== undefined);
            verify(mark.chip);                  // the chosen option's chip is shown in the field
            verify(mark.width > 0);
            root.blend = "c";
            compare(mark.iconName, "settings");
            const plain = make(bound, { y: 40 });
            compare(find(plain.contentItem, i => i.chip !== undefined).width, 0);
        }

        // ---- filtering a long list

        function test_typing_filters_a_long_list() {
            root.blend = "Arial";
            const combo = make(fonts);
            verify(combo.filterable);
            mouseClick(combo);
            tryVerify(() => combo.popup.opened);
            verify(find(combo.popup.contentItem, i => i.objectName === "filterBar").visible);

            keyClick("g");
            compare(combo.filterText, "g");
            tryCompare(options(combo), "contentHeight", 3 * (Theme.controlHeight + 2));
            compare(shownOptions(combo), ["Garamond", "Georgia", "Gill Sans"]);
            keyClick("e");
            compare(shownOptions(combo), ["Georgia"]);
            keyClick(Qt.Key_Backspace);
            compare(shownOptions(combo).length, 3);
            compare(root.blend, "Arial");       // filtering chooses nothing

            keyClick(Qt.Key_Down);              // the highlight stayed on Georgia; Down goes on
            keyClick(Qt.Key_Return);
            tryVerify(() => !combo.popup.visible);
            compare(root.blend, "Gill Sans");
        }

        function test_filter_with_no_match_and_escape() {
            root.blend = "Arial";
            const combo = make(fonts);
            mouseClick(combo);
            tryVerify(() => combo.popup.opened);
            keyClick("z");
            keyClick("z");
            compare(shownOptions(combo), []);
            keyClick(Qt.Key_Return);            // nothing to choose
            wait(30);
            verify(combo.popup.visible);
            keyClick(Qt.Key_Escape);            // first Esc clears the filter…
            compare(combo.filterText, "");
            verify(combo.popup.visible);
            keyClick(Qt.Key_Escape);            // …the second closes the list
            tryVerify(() => !combo.popup.visible);
            compare(root.blend, "Arial");

            mouseClick(combo);                  // it opens unfiltered again
            tryVerify(() => combo.popup.opened);
            compare(combo.filterText, "");
            keyClick(Qt.Key_Escape);
            tryVerify(() => !combo.popup.visible);
        }

        function test_short_lists_have_no_filter() {
            const combo = make(bound);
            verify(!combo.filterable);
            mouseClick(combo);
            tryVerify(() => combo.popup.opened);
            verify(!find(combo.popup.contentItem, i => i.objectName === "filterBar").visible);
            keyClick("s");
            compare(combo.filterText, "");
            keyClick(Qt.Key_Escape);
            tryVerify(() => !combo.popup.visible);
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
