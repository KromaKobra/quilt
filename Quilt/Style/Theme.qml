pragma Singleton
import QtQuick

// The one set of design tokens that docking and controls both draw from.
// Override any of them at start-up, or bind them, to restyle a whole app:
//
//     Component.onCompleted: { Theme.accent = "#ff8a3d"; Theme.dark = false; }
//
// Colours follow `dark` until you assign your own. docs/visual-design.md
// explains what each role is for.
QtObject {
    id: theme

    property bool dark: true

    // Surfaces, from furthest to nearest
    property color canvas: dark ? "#0e0f12" : "#e4e6ea"         // behind the panels, in the gaps
    property color surface: dark ? "#1a1c20" : "#fafafb"        // a panel, tab strip included
    property color raised: dark ? "#23262b" : "#ffffff"         // popups, menus, tooltips
    property color control: dark ? "#272a30" : "#eceef1"        // a field or button at rest
    property color controlHover: dark ? "#2f3239" : "#e2e5e9"
    property color controlFill: dark ? "#3a3e47" : "#d2d6dc"    // filled part of a ranged field, a selected segment
    property color border: dark ? "#2d3037" : "#dadde2"         // hairlines, popup edges
    property color controlBorder: "transparent"                 // outline of every control; set for high contrast
    property color shadow: dark ? "transparent" : Qt.rgba(0.1, 0.12, 0.16, 0.12)  // under popups; transparent: none

    // Text
    property color text: dark ? "#e4e6ea" : "#1b1d21"           // values, the current tab, section titles
    property color textSecondary: dark ? "#9ca1ab" : "#565c66"  // labels, other tabs, glyphs
    property color textTertiary: dark ? "#787d87" : "#7b818b"   // placeholders, disabled text, captions

    // Meaning. The accent marks what is the user's: focus, selection, "on".
    property color accent: dark ? "#4c8dff" : "#2a66dd"
    property color accentInk: dark ? "#0e0f12" : "#ffffff"      // glyphs drawn on the accent
    property color driven: dark ? "#a98bf5" : "#6f4ad3"         // a value something else computes
    property color error: dark ? "#f0616d" : "#c92f3a"
    property color warning: dark ? "#e0a53a" : "#946000"
    property color danger: "#e5484d"                            // the window close button, hovered
    property color selection: alpha(accent, 0.18)               // a selected row
    property color textSelection: alpha(accent, 0.38)
    property color rowHover: alpha(text, dark ? 0.035 : 0.045)

    // Type. The family is the application font unless you set one.
    property string fontFamily: Application.font.family
    property int fontSize: 12
    property int fontSizeSmall: 11
    property int fontWeight: Font.Normal
    property int fontWeightStrong: Font.Medium
    property int textRenderType: Text.NativeRendering           // crisper than Qt's at 12 px

    // Sizes, on a 4 px unit
    property real controlHeight: 24
    property real rowHeight: 28                 // a property row: the control plus 4 px of air
    property real tabHeight: 32
    property real titleBarHeight: 36
    property real gap: 6                        // between panels
    property real panelPadding: 12
    property real gutter: 16                    // left of a row; holds the modified dot
    property real controlPadding: 8
    property real glyphSize: 12

    // Shape
    property real radius: 8                     // panels and popups
    property real controlRadius: 4
    property real innerRadius: 3                // a segment, a swatch, a checkbox
    property real focusWidth: 1.5

    // Motion (milliseconds). Set all three to 0 to switch motion off.
    property int durationFast: 80
    property int duration: 120
    property int durationLayout: 160

    // Behaviour shared by every control
    property real dragThreshold: 3              // pixels before a press becomes a drag
    property real coarseFactor: 10              // Shift
    property real fineFactor: 0.1               // Ctrl
    property int toolTipDelay: 600
    property int popupType: 0                   // Popup.Item; 1 (Popup.Window) lets popups leave the window

    property double _toolTipSeen: 0             // internal: when a tooltip last showed

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Blends `a` towards `b` by t (0..1).
    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // The speed multiplier for a drag, key or wheel step with these modifiers.
    function stepFactor(modifiers: int): real {
        if (modifiers & Qt.ShiftModifier)
            return coarseFactor;
        if (modifiers & Qt.ControlModifier)
            return fineFactor;
        return 1;
    }
}
