pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quilt
import Quilt.Controls

// What assistive technology is told: each control's role, its name (the
// row label), and its value and state in words.
Item {
    id: root
    width: 420
    height: 480

    property real opacityValue: 0.62

    Inspector {
        id: inspector
        anchors.fill: parent

        PropertyRow {
            id: opacityRow
            label: "Opacity"
            NumberField { id: opacity; value: root.opacityValue; defaultValue: 1; from: 0; to: 1; displayScale: 100; suffix: "%"
                          onEdited: v => root.opacityValue = v }
        }
        PropertyRow { label: "Width"; NumberField { id: width_; value: 12; suffix: " px" } }
        PropertyRow { label: "Angle"; NumberField { id: angle; value: 45; paramState: Param.Driven; message: "= width * 2" } }
        PropertyRow { label: "Count"; NumberField { id: count; paramState: Param.Mixed } }
        PropertyRow { label: "Named"; NumberField { id: named; Accessible.name: "My own name" } }
        PropertyRow { label: "Position"; VectorField { id: vector; value: Qt.vector2d(3, 4) } }
        PropertyRow { label: "Visible"; CheckBox { id: check; checked: true } }
        PropertyRow { label: "Blend"; ComboBox { id: combo; model: ["Normal", "Multiply"] } }
        PropertyRow { label: "Fill"; ColorField { id: fill; value: "#4c8dff" } }
        PropertyRow { label: "Align"; SegmentedButton { id: align; model: ["Left", "Right"]; value: "Right" } }
        PropertyRow { label: "Notes"; TextArea { id: notes; text: "Hello" } }
        PropertyRow { label: "Due"; DateField { id: due; value: new Date(2026, 10, 12) } }
        Section { id: section; title: "Advanced"; PropertyRow { label: "Depth"; NumberField { } } }
    }

    Knob { id: knob; x: 300; y: 400; text: "Gain"; value: 0.5 }
    Slider { id: slider; x: 100; y: 440; value: 0.25 }
    IconButton { id: iconButton; x: 20; y: 440; iconName: "reset"; tip: "Reset view" }

    TestCase {
        name: "Accessibility"
        when: windowShown

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

        function test_the_row_label_names_the_control() {
            compare(opacity.Accessible.name, "Opacity");
            compare(check.Accessible.name, "Visible");
            compare(combo.Accessible.name, "Blend");
            compare(fill.Accessible.name, "Fill");
            compare(vector.Accessible.name, "Position");
            opacityRow.label = "Alpha";
            compare(opacity.Accessible.name, "Alpha");
            opacityRow.label = "Opacity";
            compare(named.Accessible.name, "My own name");     // a name the application gave is kept
        }

        // (Controls built on a Qt template, such as CheckBox and ComboBox,
        // get their role from the template once a screen reader is running.)
        function test_roles() {
            compare(opacity.Accessible.role, Accessible.Slider);       // it has a range
            compare(width_.Accessible.role, Accessible.SpinBox);
            compare(fill.Accessible.role, Accessible.ColorChooser);
            compare(knob.Accessible.role, Accessible.Dial);
            compare(slider.Accessible.role, Accessible.Slider);
            compare(due.Accessible.role, Accessible.EditableText);
        }

        function test_value_and_state_are_described() {
            compare(opacity.Accessible.description, "62%, modified");
            compare(width_.Accessible.description, "12 px");
            compare(angle.Accessible.description, "45, driven, = width * 2");
            compare(count.Accessible.description, "mixed");
            compare(fill.Accessible.description, "#4C8DFF");
            compare(due.Accessible.description, "2026-11-12");
            compare(knob.Accessible.description, "0.5");
            root.opacityValue = 1;
            compare(opacity.Accessible.description, "100%");
            root.opacityValue = 0.62;
        }

        function test_names_without_a_row() {
            compare(knob.Accessible.name, "Gain");             // its caption
            compare(iconButton.Accessible.name, "Reset view");  // its tooltip
            const x = find(vector, i => i.lead === "X");
            compare(x.Accessible.name, "X");
        }

        function test_segments_are_radio_buttons() {
            const right = find(align, i => i.Accessible.name === "Right" && i.Accessible.role === Accessible.RadioButton);
            verify(right);
            verify(right.Accessible.checked);
            const left = find(align, i => i.Accessible.name === "Left" && i.Accessible.role === Accessible.RadioButton);
            verify(!left.Accessible.checked);
        }

        function test_text_area_names_its_text_item() {
            const text = find(notes, i => i !== notes && i.Accessible.name === "Notes");
            verify(text);                       // the wrapper stays out of the way
            verify(text.cursorPosition !== undefined);
            verify(notes.Accessible.ignored);
        }

        function test_section_header_is_a_button() {
            const header = find(section, i => i.objectName === "header");
            compare(header.Accessible.role, Accessible.Button);
            compare(header.Accessible.name, "Advanced");
            compare(header.Accessible.description, "expanded");
            section.expanded = false;
            compare(header.Accessible.description, "collapsed");
            section.expanded = true;
        }
    }
}
