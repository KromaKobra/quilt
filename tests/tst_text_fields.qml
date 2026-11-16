import QtQuick
import QtTest
import Quilt.Controls

// TextField and TextArea: commit on Enter or focus loss, revert on Esc.
Item {
    id: root
    width: 420
    height: 400

    property string name: "Cube"
    property var log: []

    Component {
        id: bound
        TextField {
            width: 200
            text: root.name
            onEditStarted: root.log.push("start")
            onEdited: v => { root.log.push(v); root.name = v; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }
    Component { id: plain; TextField { width: 200 } }

    Component {
        id: boundArea
        TextArea {
            width: 200
            text: root.name
            onEditStarted: root.log.push("start")
            onEdited: v => { root.log.push(v); root.name = v; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }

    TestCase {
        name: "TextFields"
        when: windowShown

        function init() {
            root.name = "Cube";
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

        function test_enter_commits_once() {
            const f = make(bound);
            mouseClick(f, 150, 12);             // a click places the caret (here: at the end)
            verify(f.activeFocus);
            type("s");
            compare(root.name, "Cube");         // not live: nothing yet
            keyClick(Qt.Key_Return);
            compare(root.name, "Cubes");
            compare(root.log, ["start", "Cubes", "commit"]);
            keyClick(Qt.Key_Return);            // nothing new typed: not an edit
            compare(root.log.length, 3);
        }

        function test_focus_loss_commits() {
            const f = make(bound);
            const other = make(plain, { y: 40 });
            mouseClick(f, 150, 12);
            type("!");
            mouseClick(other, 20, 12);
            compare(root.name, "Cube!");
            compare(root.log, ["start", "Cube!", "commit"]);
        }

        function test_escape_reverts() {
            const f = make(bound);
            mouseClick(f, 150, 12);
            type("xyz");
            compare(f.text, "Cubexyz");
            keyClick(Qt.Key_Escape);
            compare(f.text, "Cube");
            compare(root.name, "Cube");
            compare(root.log, []);
        }

        function test_entering_and_leaving_changes_nothing() {
            const f = make(bound);
            const other = make(plain, { y: 40 });
            mouseClick(f, 150, 12);
            mouseClick(other, 20, 12);
            compare(root.log, []);
        }

        function test_tab_selects_all() {
            const f = make(bound);
            f.forceActiveFocus(Qt.TabFocusReason);
            compare(f.selectedText, "Cube");
            type("Ball");                       // so typing replaces
            keyClick(Qt.Key_Return);
            compare(root.name, "Ball");
        }

        function test_live_reports_each_keystroke_as_one_transaction() {
            const f = make(bound, { live: true });
            mouseClick(f, 150, 12);
            type("12");
            compare(root.name, "Cube12");
            keyClick(Qt.Key_Return);
            compare(root.log, ["start", "Cube1", "Cube12", "commit"]);

            type("3");
            keyClick(Qt.Key_Escape);            // cancel puts the text from before back
            compare(root.name, "Cube12");
            compare(root.log.slice(4), ["start", "Cube123", "Cube12", "cancel"]);
        }

        function test_refused_edit_snaps_back() {
            const f = make(plain, { text: Qt.binding(() => root.name) });
            mouseClick(f, 150, 12);
            type("zzz");
            keyClick(Qt.Key_Return);
            compare(f.text, "Cube");
            root.name = "Ball";
            compare(f.text, "Ball");
        }

        function test_unbound_field_keeps_its_text() {
            const f = make(plain);
            mouseClick(f, 20, 12);
            type("hello");
            keyClick(Qt.Key_Return);
            compare(f.text, "hello");
        }

        function test_validator_marks_and_drops_bad_input() {
            const f = make(bound, { validator: null });
            const validator = createTemporaryQmlObject('import QtQuick; RegularExpressionValidator { regularExpression: /[A-Z][a-z]+/ }', root);
            f.validator = validator;
            const other = make(plain, { y: 40 });
            mouseClick(f, 150, 12);
            keyClick(Qt.Key_Backspace);
            keyClick(Qt.Key_Backspace);
            keyClick(Qt.Key_Backspace);         // "C": not acceptable (yet)
            compare(f.text, "C");
            verify(!f.acceptableInput);
            mouseClick(other, 20, 12);          // leaving drops it
            compare(f.text, "Cube");
            compare(root.name, "Cube");
        }

        function test_search_field_clears() {
            const f = make(bound, { search: true, live: true });
            mouseClick(f, 150, 12);
            type("x");
            compare(root.name, "Cubex");
            mouseClick(f, f.width - 12, 12);    // the clear button
            compare(root.name, "");
            compare(f.text, "");
        }

        function test_mixed_and_driven() {
            const f = make(bound, { paramState: Param.Mixed });
            mouseClick(f, 20, 12);
            compare(f.text, "");                // typed over from empty
            type("All");
            keyClick(Qt.Key_Return);
            compare(root.name, "All");

            const driven = make(bound, { y: 40, paramState: Param.Driven, expression: "other.name", acceptsExpressions: true });
            let expression = null;
            driven.expressionEdited.connect(text => expression = text);
            mouseClick(driven, 20, 12);
            compare(driven.text, "=other.name");    // editing shows the expression
            keyClick(Qt.Key_Escape);
            keyClick(Qt.Key_Tab);
            compare(driven.text, "All");
            mouseClick(driven, 180, 12);
            type("2");
            keyClick(Qt.Key_Return);
            compare(expression, "other.name2");
            compare(driven.text, "All");
            compare(root.name, "All");
        }

        function test_read_only() {
            const f = make(bound, { readOnly: true });
            mouseClick(f, 150, 12);
            type("x");
            keyClick(Qt.Key_Return);
            compare(root.name, "Cube");
            f.pasteText("y");
            compare(root.name, "Cube");
        }

        function test_modified_and_reset() {
            const f = make(bound, { defaultValue: "Thing" });
            verify(f.modified);
            f.reset();
            compare(root.name, "Thing");
            verify(!f.modified);
        }

        // ---- TextArea

        function test_area_enter_adds_a_line_and_ctrl_enter_commits() {
            const a = make(boundArea);
            mouseClick(a, 150, 40);
            verify(a.editing);
            keyClick(Qt.Key_End, Qt.ControlModifier);
            keyClick(Qt.Key_Return);
            type("two");
            compare(root.name, "Cube");
            keyClick(Qt.Key_Return, Qt.ControlModifier);
            compare(root.name, "Cube\ntwo");
            compare(root.log, ["start", "Cube\ntwo", "commit"]);
        }

        function test_area_escape_reverts_and_focus_loss_commits() {
            const a = make(boundArea);
            const other = make(plain, { y: 150 });
            mouseClick(a, 150, 40);
            type("x");
            keyClick(Qt.Key_Escape);
            compare(a.text, "Cube");
            compare(root.log, []);
            type("y");
            mouseClick(other, 20, 12);
            compare(root.name.indexOf("y") >= 0, true);
            compare(root.log.length, 3);
        }

        function test_area_grows_to_its_maximum() {
            const a = make(boundArea, { minimumLines: 2, maximumLines: 4 });
            const two = a.implicitHeight;
            root.name = "1\n2\n3";
            verify(a.implicitHeight > two);
            const three = a.implicitHeight;
            root.name = "1\n2\n3\n4\n5\n6\n7";
            const capped = a.implicitHeight;
            verify(capped > three);
            root.name = "1\n2\n3\n4\n5\n6\n7\n8\n9";
            compare(a.implicitHeight, capped);
        }

        function test_area_wheel_scrolls_its_text_only_when_focused() {
            const a = make(boundArea, { minimumLines: 2, maximumLines: 2 });
            root.name = "1\n2\n3\n4\n5\n6\n7\n8\n9";
            const flick = a.contentItem;
            mouseWheel(a, 50, 20, 0, -240);
            compare(flick.contentY, 0);
            mouseClick(a, 50, 20);
            mouseWheel(a, 50, 20, 0, -240);
            tryVerify(() => flick.contentY > 0);
        }
    }
}
