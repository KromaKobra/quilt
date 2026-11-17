pragma ComponentBehavior: Bound
import QtQuick

// The surface of anything that floats over the interface: a menu, a
// dropdown list, a picker, a tooltip.
//
//     T.Popup { background: PopupBackground { } }
//
// With Theme.shadow set (the light theme sets it) it casts a soft shadow,
// drawn as a few widening rings rather than with a shader. The dark theme
// has none: a lighter surface already reads as nearer there. A theme
// redraws it with `skins.popup` (`skins.toolTip` for a tooltip's).
Surface {
    id: surface

    slot: "popup"
    radius: Theme.radius
    fill: Theme.raised
    edge: Theme.border

    Repeater {
        model: !surface.skinned && Theme.shadow.a > 0 ? 4 : 0
        delegate: Rectangle {
            required property int index
            readonly property real spread: index + 1
            z: -1                               // behind the surface
            anchors {
                fill: parent
                leftMargin: -spread
                rightMargin: -spread
                topMargin: -spread + 2          // light comes from above
                bottomMargin: -spread - 2
            }
            radius: surface.radius + spread
            color: Theme.alpha(Theme.shadow, Theme.shadow.a / 4)
        }
    }
}
