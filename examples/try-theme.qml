// The gallery under a theme of your own. Edit the ThemeSpec below and run
// it again from the repository root:
//
//     qml6 -I . examples/try-theme.qml
//
// docs/try-themes-and-layouts.md explains what you can change.
import QtQuick
import Quilt.Controls

QtObject {
    property ThemeSpec paper: ThemeSpec {
        name: "Paper"
        modes: ThemeSpec.LightOnly
        canvas: "#efe9dd"
        surface: "#faf7f0"
        raised: "#ffffff"
        control: "#f1ece2"
        controlHover: "#e8e1d3"
        controlFill: "#ddd4c2"
        border: "#d6cdbb"
        accent: "#c2410c"
        radius: 2
        controlRadius: 0
        innerRadius: 0
        duration: 200
        easing: Easing.OutQuad

        // Fields become a single rule underneath: no box. A painter draws
        // everything the host would have: here, a ranged number's level.
        skins.field: Component {
            Item {
                id: underline
                readonly property Face host: parent as Face
                Rectangle {
                    visible: !!underline.host && underline.host.leveled
                    width: underline.host ? Math.round(underline.width * underline.host.level) : 0
                    height: underline.height
                    color: Theme.alpha(Theme.accent, underline.host && underline.host.levelActive ? 0.25 : 0.12)
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: underline.host && (underline.host.hovered || underline.host.focused) ? 2 : 1
                    color: underline.host && underline.host.focused ? Theme.accent : Theme.textTertiary
                    visible: !!underline.host && !underline.host.flat
                }
            }
        }
    }

    Component.onCompleted: {
        Theme.spec = paper;
        Qt.createComponent("gallery.qml").createObject(null);
    }
}
