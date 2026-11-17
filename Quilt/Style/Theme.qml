pragma Singleton
import QtQuick
import QtQuick.Shapes

// The one set of design tokens that docking and controls both draw from.
// Override any of them at start-up, or bind them, to restyle a whole app:
//
//     Component.onCompleted: { Theme.accent = "#ff8a3d"; Theme.dark = false; }
//
// Each token follows the current theme, `spec`, until you assign your own;
// an assigned token keeps its value when the theme changes. A Binding on a
// token gives it back to the theme when the Binding is released.
// docs/visual-design.md explains what each role is for, docs/themes.md how
// themes work.
QtObject {
    id: theme

    property bool dark: true

    // The theme. `quilt` is Quilt's own; Quilt.Themes has more. `feel`, when
    // set, takes motion, metrics and behaviour from another theme than the
    // look, so the two can be compared separately.
    readonly property ThemeSpec quilt: ThemeSpec { }
    property ThemeSpec spec: quilt
    property ThemeSpec feel: null
    // What the tokens read: Quilt's own when the spec is gone (destroyed
    // while in use: its window closed, say). Functions, not properties: a
    // property holding the spec would be cleared along with it.
    function _look(): ThemeSpec { return spec ?? quilt; }
    function _feel(): ThemeSpec { return feel ?? spec ?? quilt; }
    readonly property Skins skins: _look().skins

    // Preferences that apply under any theme.
    property bool reduceMotion: false           // every duration 0: nothing animates
    property bool reduceTransparency: false     // themes draw solid surfaces instead of glass and glows

    // Surfaces, from furthest to nearest
    property color canvas: _look().canvas               // behind the panels, in the gaps
    property color surface: _look().surface             // a panel, tab strip included
    property color raised: _look().raised               // popups, menus, tooltips
    property color control: _look().control             // a field or button at rest
    property color controlHover: _look().controlHover
    property color controlFill: _look().controlFill     // filled part of a ranged field, a selected segment
    property color border: _look().border               // hairlines, popup edges
    property color controlBorder: _look().controlBorder // outline of every control; set for high contrast
    property color panelOutline: _look().panelOutline   // outline of every docked panel
    property color shadow: _look().shadow               // under popups; transparent: none
    property color well: _look().well                   // an app's own canvas inside a panel: a viewport

    // Text
    property color text: _look().text                   // values, the current tab, section titles
    property color textSecondary: _look().textSecondary // labels, other tabs, glyphs
    property color textTertiary: _look().textTertiary   // placeholders, disabled text, captions

    // Meaning. The accent marks what is the user's: focus, selection, "on".
    property color accent: _look().accent
    property color accentInk: _look().accentInk                        // glyphs drawn on the accent
    property color driven: _look().driven                              // a value something else computes
    property color error: _look().error
    property color warning: _look().warning
    property color danger: _look().danger                              // the window close button, hovered
    property color dangerInk: _look().dangerInk                        // a glyph drawn on `danger`
    property color selection: _look().selection ?? alpha(accent, 0.18) // a selected row
    property color textSelection: _look().textSelection ?? alpha(accent, 0.38)
    property color rowHover: _look().rowHover ?? alpha(text, dark ? 0.035 : 0.045)
    property color focus: _look().focus ?? accent                      // the focus ring
    property color fillInk: _look().fillInk ?? text                    // text on controlFill

    // Type. The family is the application font unless a theme or you set one.
    property string fontFamily: _look().fontFamily
    property string fontFamilyTitle: _look().fontFamilyTitle || fontFamily  // section titles, tabs
    property string fontFamilyValue: _look().fontFamilyValue || fontFamily  // numbers and values
    property int fontSize: _look().fontSize
    property int fontSizeSmall: _look().fontSizeSmall
    property int fontSizeTitle: _look().fontSizeTitle || fontSize
    property int fontWeight: _look().fontWeight
    property int fontWeightStrong: _look().fontWeightStrong
    property int titleCapitalization: _look().titleCapitalization
    property real titleLetterSpacing: _look().titleLetterSpacing
    property int textRenderType: _look().textRenderType                     // native: crisper than Qt's at 12 px

    // Sizes, on a 4 px unit
    property real controlHeight: _feel().controlHeight
    property real rowHeight: _feel().rowHeight          // a property row: the control plus 4 px of air
    property real tabHeight: _feel().tabHeight
    property real titleBarHeight: _feel().titleBarHeight
    property real gap: _feel().gap                      // between panels
    property real panelPadding: _feel().panelPadding
    property real gutter: _feel().gutter                // left of a row; holds the modified dot
    property real controlPadding: _feel().controlPadding
    property real glyphSize: _feel().glyphSize

    // Shape
    property real radius: _look().radius                // panels and popups
    property real controlRadius: _look().controlRadius
    property real innerRadius: _look().innerRadius      // a segment, a swatch, a checkbox
    property real focusWidth: _look().focusWidth
    property real focusOffset: _look().focusOffset      // the focus ring's distance outside a control
    property real controlBorderWidth: _look().controlBorderWidth
    property real outlineWidth: _look().outlineWidth
    readonly property real paintOverflow: 12            // how far a theme's painter may draw outside its item

    // Icons
    property real iconStrokeWidth: _look().iconStrokeWidth
    property int iconCap: _look().iconCap
    property var icons: _look().icons                   // name → path, replacing Quilt's glyphs
    readonly property int _iconJoin: iconCap === ShapePath.RoundCap ? ShapePath.RoundJoin : ShapePath.MiterJoin

    // Motion (milliseconds). reduceMotion sets all three to 0.
    property int durationFast: reduceMotion ? 0 : _feel().durationFast
    property int duration: reduceMotion ? 0 : _feel().duration
    property int durationLayout: reduceMotion ? 0 : _feel().durationLayout
    property int easing: _feel().easing                 // every transition's curve

    // How the current theme feels. docs/themes.md describes each.
    property bool hoverReveal: _feel().hoverReveal      // dock buttons show on hover only
    property bool hoverFadeIn: _feel().hoverFadeIn && !reduceMotion
    property real pressTravel: _feel().pressTravel
    property int caretStyle: _feel().caretStyle
    property int knobDrag: _feel().knobDrag
    property bool drawIn: _feel().drawIn && !reduceMotion

    // Behaviour shared by every control. Never part of a theme: these are
    // how the controls work, and they stay the same under every look.
    property real dragThreshold: 3              // pixels before a press becomes a drag
    property real coarseFactor: 10              // Shift
    property real fineFactor: 0.1               // Ctrl
    property int toolTipDelay: 600
    property int popupType: 0                   // Popup.Item; 1 (Popup.Window) lets popups leave the window

    property double _toolTipSeen: 0             // internal: when a tooltip last showed
    readonly property bool _ownCaret: caretStyle !== ThemeSpec.Line     // internal: text fields use Caret
    property bool _preferDark: true             // internal: the mode to return to after a one-mode theme

    // A theme that has only a dark or a light version decides `dark`; one
    // with both follows what was last chosen. The spec learns the mode last,
    // so its colours change in one step.
    onSpecChanged: {
        if (!spec) {
            spec = quilt;
            return;
        }
        if (spec.modes === ThemeSpec.Both)
            dark = _preferDark;
        _syncMode();
    }
    onDarkChanged: {
        if (_look().modes === ThemeSpec.Both)
            _preferDark = dark;
        _syncMode();
    }
    Component.onCompleted: _syncMode()

    function _syncMode() {
        if (_look().modes === ThemeSpec.DarkOnly && !dark)
            dark = true;
        else if (_look().modes === ThemeSpec.LightOnly && dark)
            dark = false;
        else
            _look().dark = dark;
    }

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
