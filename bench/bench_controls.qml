pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quilt
import Quilt.Controls

// What it costs to build Quilt's interface: a 300-row inspector and a
// docking area with six tab groups. Run with ../run-bench.sh, and compare
// the numbers before and after a change to the controls or the theme.
Item {
    id: root
    width: 1200
    height: 900

    Component {
        id: inspector
        Inspector {
            anchors.fill: parent
            Section {
                title: "Numbers"
                Repeater {
                    model: 100
                    PropertyRow {
                        required property int index
                        label: "Number " + index
                        NumberField { value: index; from: 0; to: 500 }
                    }
                }
            }
            Section {
                title: "Toggles"
                Repeater {
                    model: 50
                    PropertyRow {
                        required property int index
                        label: "Check " + index
                        CheckBox { checked: index % 2 === 0 }
                    }
                }
                Repeater {
                    model: 50
                    PropertyRow {
                        required property int index
                        label: "Switch " + index
                        Switch { checked: index % 3 === 0 }
                    }
                }
            }
            Section {
                title: "Choices"
                Repeater {
                    model: 50
                    PropertyRow {
                        required property int index
                        label: "Choice " + index
                        ComboBox { model: ["Low", "Medium", "High"]; value: "Medium" }
                    }
                }
                Repeater {
                    model: 50
                    PropertyRow {
                        required property int index
                        label: "Colour " + index
                        ColorField { value: Qt.hsva(index / 50, 0.6, 0.9, 1) }
                    }
                }
            }
        }
    }

    Component {
        id: dock
        DockArea {
            anchors.fill: parent
            style.animationDuration: 0
            DockPanel { panelId: "a"; title: "Alpha" }
            DockPanel { panelId: "b"; title: "Beta"; area: Dock.Left }
            DockPanel { panelId: "c"; title: "Gamma"; area: Dock.Right }
            DockPanel { panelId: "d"; title: "Delta"; area: Dock.Bottom }
            DockPanel { panelId: "e"; title: "Epsilon"; area: Dock.Top }
            DockPanel { panelId: "f"; title: "Zeta"; area: Dock.Right }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        // Compile every type once, so the benchmarks time creation alone.
        function initTestCase() {
            inspector.createObject(root).destroy();
            dock.createObject(root).destroy();
            wait(50);
        }

        function benchmark_inspector_300_rows() {
            const item = inspector.createObject(root);
            item.destroy();
        }

        function benchmark_dock_area_6_groups() {
            const item = dock.createObject(root);
            item.destroy();
        }
    }
}
