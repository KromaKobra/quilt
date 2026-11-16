import QtQuick
import QtTest
import Quilt.Controls

// Slider and Knob: the two continuous controls for use outside a grid.
Item {
    id: root
    width: 420
    height: 400

    property real v: 0.5
    property var log: []

    Component {
        id: slider
        Slider {
            width: 212                          // 200 px of travel plus the thumb
            value: root.v
            onEditStarted: root.log.push("start")
            onEdited: x => { root.log.push(x); root.v = x; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }
    Component { id: freeSlider; Slider { width: 212 } }

    Component {
        id: knob
        Knob {
            text: "Gain"
            value: root.v
            onEditStarted: root.log.push("start")
            onEdited: x => { root.log.push(x); root.v = x; }
            onEditFinished: committed => root.log.push(committed ? "commit" : "cancel")
        }
    }

    TestCase {
        name: "SliderKnob"
        when: windowShown

        function init() {
            root.v = 0.5;
            root.log = [];
        }

        function make(component, properties) {
            const item = createTemporaryObject(component, root, properties || {});
            verify(item);
            return item;
        }

        function signals() { return root.log.filter(x => typeof x === "string"); }

        // ---- Slider

        function test_slider_grabbing_the_thumb_does_not_jump() {
            const s = make(slider);
            mousePress(s, 108, 12);             // 2 px right of the thumb's centre
            compare(root.v, 0.5);
            mouseMove(s, 128, 12, -1, Qt.LeftButton);
            fuzzyCompare(root.v, 0.6, 1e-9);    // moved by exactly the pointer's travel
            mouseRelease(s, 128, 12);
            compare(signals(), ["start", "commit"]);
        }

        function test_slider_pressing_the_track_goes_there_and_keeps_dragging() {
            const s = make(slider);
            mousePress(s, 6 + 40, 12);
            fuzzyCompare(root.v, 0.2, 1e-9);
            mouseMove(s, 6 + 60, 12, -1, Qt.LeftButton);
            fuzzyCompare(root.v, 0.3, 1e-9);
            mouseMove(s, 500, 12, -1, Qt.LeftButton);
            compare(root.v, 1);
            mouseRelease(s, 500, 12);
            compare(signals(), ["start", "commit"]);
        }

        function test_slider_escape_cancels() {
            const s = make(slider);
            mousePress(s, 46, 12);
            mouseMove(s, 80, 12, -1, Qt.LeftButton);
            verify(root.v !== 0.5);
            keyClick(Qt.Key_Escape);
            compare(root.v, 0.5);
            mouseMove(s, 120, 12, -1, Qt.LeftButton);
            compare(root.v, 0.5);
            mouseRelease(s, 120, 12);
            compare(signals(), ["start", "cancel"]);
        }

        function test_slider_steps() {
            const s = make(slider, { from: 0, to: 10, stepSize: 1 });
            root.v = 4;
            mousePress(s, 6 + 130, 12);         // 6.5 along: lands on a whole step
            compare(root.v, 7);
            mouseRelease(s, 136, 12);
            s.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Right);
            compare(root.v, 8);
            keyClick(Qt.Key_Down);
            compare(root.v, 7);
            keyClick(Qt.Key_Home);
            compare(root.v, 0);
            keyClick(Qt.Key_End);
            compare(root.v, 10);
        }

        function test_slider_keys_and_wheel() {
            const s = make(slider);
            mouseWheel(s, 50, 12, 0, 120);
            compare(root.v, 0.5);               // no focus: ignored
            s.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Right);
            fuzzyCompare(root.v, 0.51, 1e-9);
            keyClick(Qt.Key_Right, Qt.ShiftModifier);
            fuzzyCompare(root.v, 0.61, 1e-9);
            mouseWheel(s, 50, 12, 0, -120);
            fuzzyCompare(root.v, 0.6, 1e-9);
            keyClick(Qt.Key_Escape);            // the whole run of steps is undone
            compare(root.v, 0.5);
        }

        function test_slider_snaps_to_its_default() {
            const s = make(slider, { defaultValue: 0.75 });
            mousePress(s, 6 + 148, 12);         // 0.74: within reach of the default
            compare(root.v, 0.75);
            mouseMove(s, 6 + 152, 12, -1, Qt.LeftButton, Qt.ControlModifier);
            fuzzyCompare(root.v, 0.76, 1e-9);   // Ctrl passes freely
            mouseRelease(s, 158, 12);
        }

        function test_slider_vertical() {
            const s = make(freeSlider, { orientation: Qt.Vertical, width: 24, height: 212, value: 0 });
            mousePress(s, 12, 6 + 50);          // a quarter down from the top
            fuzzyCompare(s.value, 0.75, 1e-9);
            mouseRelease(s, 12, 56);
            s.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            fuzzyCompare(s.value, 0.76, 1e-9);
        }

        function test_slider_refused_live_and_states() {
            const s = make(freeSlider, { value: Qt.binding(() => root.v) });
            mousePress(s, 46, 12);
            mouseRelease(s, 46, 12);
            compare(s.value, 0.5);              // nobody took the edit: back where it was

            const late = make(slider, { y: 30, live: false });
            mousePress(late, 46, 12);
            mouseMove(late, 86, 12, -1, Qt.LeftButton);
            compare(root.v, 0.5);
            fuzzyCompare(late.position, 0.4, 1e-9);     // the thumb still follows
            mouseRelease(late, 86, 12);
            fuzzyCompare(root.v, 0.4, 1e-9);

            root.v = 0.5;
            const driven = make(slider, { y: 60, paramState: Param.Driven });
            mousePress(driven, 46, 12);
            mouseRelease(driven, 46, 12);
            const readOnly = make(slider, { y: 90, readOnly: true });
            mousePress(readOnly, 46, 12);
            mouseRelease(readOnly, 46, 12);
            compare(root.v, 0.5);
        }

        // ---- Knob

        function test_knob_drags_vertically() {
            const k = make(knob);
            mousePress(k, 20, 20);
            mouseMove(k, 20, 18, -1, Qt.LeftButton);
            compare(root.v, 0.5);               // under the threshold
            mouseMove(k, 20, 17, -1, Qt.LeftButton);
            mouseMove(k, 20, -23, -1, Qt.LeftButton);   // 40 px up: a fifth of the range
            fuzzyCompare(root.v, 0.7, 1e-9);
            mouseMove(k, 20, -400, -1, Qt.LeftButton);
            compare(root.v, 1);
            mouseMove(k, 20, -380, -1, Qt.LeftButton);  // no dead travel on the way back
            fuzzyCompare(root.v, 0.9, 1e-9);
            mouseRelease(k, 20, -380);
            compare(signals(), ["start", "commit"]);
        }

        function test_knob_escape_cancels() {
            const k = make(knob);
            mousePress(k, 20, 20);
            mouseMove(k, 20, 10, -1, Qt.LeftButton);
            mouseMove(k, 20, -20, -1, Qt.LeftButton);
            verify(root.v > 0.5);
            keyClick(Qt.Key_Escape);
            compare(root.v, 0.5);
            mouseMove(k, 20, -60, -1, Qt.LeftButton);
            compare(root.v, 0.5);
            mouseRelease(k, 20, -60);
            compare(signals(), ["start", "cancel"]);
        }

        function test_knob_keys_and_wheel() {
            const k = make(knob);
            mouseWheel(k, 20, 20, 0, 120);
            compare(root.v, 0.5);
            k.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            fuzzyCompare(root.v, 0.51, 1e-9);
            keyClick(Qt.Key_Up, Qt.ShiftModifier);
            fuzzyCompare(root.v, 0.61, 1e-9);
            keyClick(Qt.Key_Down, Qt.ControlModifier);
            fuzzyCompare(root.v, 0.609, 1e-9);
            mouseWheel(k, 20, 20, 0, 120);
            fuzzyCompare(root.v, 0.62, 1e-9);
        }

        function test_knob_click_types_a_value() {
            const k = make(knob);
            mouseClick(k, 20, 20);
            keyClick("0");
            keyClick(".");
            keyClick("2");
            keyClick("5");
            keyClick(Qt.Key_Return);
            compare(root.v, 0.25);
            compare(signals(), ["start", "commit"]);

            mouseClick(k, 20, 20);              // beyond the range: clamped
            keyClick("7");
            keyClick(Qt.Key_Return);
            compare(root.v, 1);
        }

        function test_knob_display() {
            const k = make(knob, { displayScale: 100, suffix: "%", decimals: 0, valueVisible: true });
            compare(k.displayText, "50%");
            const bipolar = make(knob, { x: 80, from: -1, to: 1, bipolar: true });
            root.v = 0;
            compare(bipolar.position, 0.5);
        }

        function test_knob_states() {
            const driven = make(knob, { paramState: Param.Driven });
            mousePress(driven, 20, 20);
            mouseMove(driven, 20, 0, -1, Qt.LeftButton);
            mouseMove(driven, 20, -40, -1, Qt.LeftButton);
            mouseRelease(driven, 20, -40);
            compare(root.v, 0.5);
            const mixed = make(knob, { x: 80, paramState: Param.Mixed });
            compare(mixed.displayText, "Mixed");
            mixed.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Up);
            compare(root.v, 0.5);
            compare(root.log, []);
        }
    }
}
