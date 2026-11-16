pragma ComponentBehavior: Bound

// Every Quilt control, in every state, without any docking. Run from the
// repository root:
//
//     qml6 -I . examples/gallery.qml
//
// The left column is an Inspector built by hand. The right column holds the
// controls that live outside a property grid.
import QtQuick
import Quilt.Controls

ApplicationWindow {
    id: window
    width: 980
    height: 760
    minimumWidth: 640
    minimumHeight: 420
    visible: true
    frameless: true
    title: "Quilt controls"

    // The "document" the controls edit.
    QtObject {
        id: shape
        property string name: "Cube"
        property vector3d position: Qt.vector3d(120, 48, 0)
        property real rotation: 45
        property vector2d scale: Qt.vector2d(1.5, 1.5)
        property real opacity: 0.62
        property string blend: "Normal"
        property color fill: "#4c8dff"
        property string align: "Center"
        property var styles: ["bold"]
        property bool visible: true
        property bool shadows: true
        property int segments: 12
        property real frequency: 440
        property date due: new Date(2026, 10, 12, 14, 30)
        property string notes: "Drag a number sideways to change it.\nClick it to type. Arithmetic works: 2*pi, +=10."
    }

    menuBar: TitleBar {
        Menu {
            title: "File"
            Action { text: "Quit"; shortcut: StandardKey.Quit; onTriggered: Qt.quit() }
        }
        Menu {
            title: "View"
            Action { text: "Dark theme"; checkable: true; checked: Theme.dark; onTriggered: Theme.dark = !Theme.dark }
            Action { text: "High contrast"; checkable: true; checked: Theme.controlBorder.a > 0
                     onTriggered: Theme.controlBorder = Theme.controlBorder.a > 0 ? "transparent" : Theme.textTertiary }
            MenuSeparator { }
            Action { text: "No motion"; checkable: true; checked: Theme.duration === 0
                     onTriggered: {
                         const off = Theme.duration !== 0;
                         Theme.durationFast = off ? 0 : 80;
                         Theme.duration = off ? 0 : 120;
                         Theme.durationLayout = off ? 0 : 160;
                     } }
        }
    }

    Row {
        anchors { fill: parent; margins: Theme.gap }
        spacing: Theme.gap

        Rectangle {
            width: 340
            height: parent.height
            radius: Theme.radius
            color: Theme.surface

            Inspector {
                anchors.fill: parent

                PropertyRow {
                    label: "Name"
                    TextField { text: shape.name; onEdited: v => shape.name = v }
                }

                Section {
                    title: "Transform"
                    PropertyRow {
                        label: "Position"
                        VectorField { value: shape.position; defaultValue: Qt.vector3d(0, 0, 0); onEdited: v => shape.position = v }
                    }
                    PropertyRow {
                        label: "Rotation"
                        NumberField { value: shape.rotation; defaultValue: 0; from: 0; to: 360; wrap: true; suffix: "°"; onEdited: v => shape.rotation = v }
                    }
                    PropertyRow {
                        label: "Scale"
                        VectorField { value: shape.scale; defaultValue: Qt.vector2d(1, 1); linkable: true; linked: true; step: 0.01; onEdited: v => shape.scale = v }
                    }
                }

                Section {
                    title: "Appearance"
                    PropertyRow {
                        label: "Opacity"
                        NumberField { value: shape.opacity; defaultValue: 1; from: 0; to: 1; displayScale: 100; suffix: "%"; onEdited: v => shape.opacity = v }
                    }
                    PropertyRow {
                        label: "Blend"
                        ComboBox { model: ["Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten", "Difference"]
                                   value: shape.blend; defaultValue: "Normal"; onEdited: v => shape.blend = v }
                    }
                    PropertyRow {
                        label: "Fill"
                        ColorField { value: shape.fill; defaultValue: "#4c8dff"; swatches: ["#f0616d", "#e0a53a", "#4fbf7b", "#4c8dff", "#a98bf5"]
                                     onEdited: c => shape.fill = c }
                    }
                    PropertyRow {
                        label: "Align"
                        SegmentedButton { model: ["Left", "Center", "Right"]; value: shape.align; onEdited: v => shape.align = v }
                    }
                    PropertyRow {
                        label: "Style"
                        fill: false
                        SegmentedButton {
                            model: [{ text: "B", value: "bold", tip: "Bold" }, { text: "I", value: "italic", tip: "Italic" },
                                    { text: "U", value: "underline", tip: "Underline" }]
                            exclusive: false
                            value: shape.styles
                            onEdited: v => shape.styles = v
                        }
                    }
                    PropertyRow {
                        label: "Visible"
                        CheckBox { checked: shape.visible; defaultValue: true; onEdited: v => shape.visible = v }
                    }
                }

                Section {
                    title: "Shadows"
                    contentEnabled: shape.shadows
                    accessory: Switch { checked: shape.shadows; onEdited: v => shape.shadows = v }
                    PropertyRow {
                        label: "Segments"
                        NumberField { value: shape.segments; integer: true; minimum: 3; maximum: 64; steppers: true; onEdited: v => shape.segments = v }
                    }
                    PropertyRow {
                        label: "Frequency"
                        description: "A logarithmic range: each drag distance multiplies the value."
                        NumberField { value: shape.frequency; from: 20; to: 20000; logarithmic: true; decimals: 0; suffix: " Hz"; onEdited: v => shape.frequency = v }
                    }
                    PropertyRow {
                        label: "Due"
                        DateField { value: shape.due; mode: "datetime"; onEdited: d => shape.due = d }
                    }
                    PropertyRow {
                        label: "Notes"
                        TextArea { text: shape.notes; onEdited: v => shape.notes = v }
                    }
                }

                Section {
                    title: "States"
                    PropertyRow { label: "Driven"; NumberField { value: shape.rotation / 2; suffix: "°"; paramState: Param.Driven; expression: "rotation / 2"; message: "Follows Rotation" } }
                    PropertyRow { label: "Mixed"; NumberField { paramState: Param.Mixed } }
                    PropertyRow { label: "Invalid"; NumberField { value: 2; paramState: Param.Invalid; expression: "2 * (3"; message: "Missing ')'" } }
                    PropertyRow { label: "Read-only"; NumberField { value: 3.14159; readOnly: true } }
                    PropertyRow { label: "Disabled"; NumberField { value: 12; enabled: false } }
                    PropertyRow { label: "Mixed"; CheckBox { paramState: Param.Mixed } }
                    PropertyRow { label: "Mixed"; ComboBox { model: ["One", "Two"]; paramState: Param.Mixed } }
                    PropertyRow { label: "Mixed"; ColorField { paramState: Param.Mixed } }
                }
            }
        }

        Rectangle {
            width: parent.width - 340 - Theme.gap
            height: parent.height
            radius: Theme.radius
            color: Theme.surface

            Column {
                anchors { fill: parent; margins: 20 }
                spacing: 18

                Label { text: "Outside a property grid"; font.weight: Theme.fontWeightStrong }

                Row {
                    spacing: 12
                    Button { text: "Cancel" }
                    Button { text: "Apply"; primary: true }
                    Button { text: "Reset"; iconName: "reset"; flat: true }
                    Button { text: "Disabled"; enabled: false }
                    IconButton { iconName: "search"; tip: "Search" }
                    IconButton { iconName: "more"; tip: "More" }
                    IconButton { iconName: "link"; tip: "Linked"; checkable: true; checked: true }
                }

                Row {
                    spacing: 16
                    Slider { width: 220; from: 0; to: 1; value: shape.opacity; defaultValue: 1; onEdited: v => shape.opacity = v }
                    Label { anchors.verticalCenter: parent.verticalCenter; dim: true; text: Math.round(shape.opacity * 100) + "%" }
                    Slider { width: 160; from: 0; to: 10; stepSize: 1; value: 4 }
                }

                Row {
                    spacing: 18
                    Knob { text: "Cutoff"; from: 20; to: 20000; step: 10; decimals: 0; suffix: " Hz"; value: shape.frequency; onEdited: v => shape.frequency = v }
                    Knob { text: "Reso"; value: 0.35; defaultValue: 0.5 }
                    Knob { text: "Pan"; from: -1; to: 1; bipolar: true; value: -0.3 }
                    Knob { text: "Drive"; value: 0.8; paramState: Param.Driven; message: "Driven by the envelope" }
                    Knob { text: "Mix"; value: 0.5; displayScale: 100; suffix: "%"; decimals: 0; valueVisible: true }
                    Slider { orientation: Qt.Vertical; height: 64; value: 0.7 }
                    Slider { orientation: Qt.Vertical; height: 64; value: 0.4 }
                }

                Row {
                    spacing: 16
                    CheckBox { text: "Snap to grid"; checked: true }
                    CheckBox { text: "Show guides" }
                    Switch { text: "Live preview"; checked: true }
                    Switch { text: "Autosave" }
                }

                Row {
                    spacing: 12
                    TextField { width: 200; search: true; placeholderText: "Search"; live: true }
                    ComboBox { width: 150; model: [{ text: "Low", value: 1 }, { text: "Medium", value: 2 }, { text: "High", value: 3 }]; value: 2 }
                    DateField { mode: "time"; seconds: true }
                }

                Row {
                    spacing: 16
                    ProgressBar { width: 200; anchors.verticalCenter: parent.verticalCenter; value: shape.opacity }
                    ProgressBar { width: 120; anchors.verticalCenter: parent.verticalCenter; indeterminate: true }
                    BusyIndicator { running: true }
                    Label { anchors.verticalCenter: parent.verticalCenter; dim: true; text: "Working…" }
                }

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    dim: true
                    text: "Try: drag a number or its label (Shift ×10, Ctrl ×0.1, Esc cancels) · click to type, e.g. 2*pi or +=10 · "
                          + "Tab to a field, then Up/Down or the wheel · click the dot beside a changed value to reset it · "
                          + "right-click a row · paste “1, 2, 3” into a vector."
                }
            }
        }
    }
}
