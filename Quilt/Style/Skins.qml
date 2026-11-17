import QtQuick

// The painters a theme supplies, one per kind of surface. A slot left null
// keeps Quilt's own look, so a theme sets only the slots it redraws:
//
//     ThemeSpec {
//         skins.field: Component { Slab { } }
//         component Slab: Rectangle {
//             readonly property Face host: parent ? parent.parent as Face : null
//             color: host ? host.fill : "transparent"
//         }
//     }
//
// Each slot is drawn by one host type (Surface, Face, FocusRing, …), which
// creates the painter in a Loader the size of the host. docs/themes.md has
// the contract a painter follows.
QtObject {
    // Surface
    property Component canvas: null     // behind everything in a window
    property Component panel: null      // a docked panel, tab strip included
    property Component popup: null      // menus, dropdown lists, pickers
    property Component toolTip: null   // tooltips; falls back to `popup`
    property Component bar: null        // a window's title bar
    property Component overlay: null    // over everything in a window: scanlines, grain (never takes input)

    // Face
    property Component field: null      // a field: number, text, dropdown, date, colour
    property Component button: null     // buttons, tool buttons, the track of a segmented button
    property Component segment: null    // the selected part of a segmented button
    property Component item: null       // a highlighted row in a menu or list; a calendar day

    // The rest
    property Component focusRing: null
    property Component check: null      // a checkbox's box
    property Component toggle: null     // a switch's track and thumb
    property Component track: null      // a slider's or progress bar's track and fill
    property Component thumb: null      // a slider's handle; a scroll bar's thumb
    property Component dial: null       // a knob's face
    property Component spinner: null    // a busy indicator
    property Component tab: null        // the mark of the current tab
    property Component rule: null       // separators and dividers
}
