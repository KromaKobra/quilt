import QtQuick
import QtQuick.Shapes

// One complete theme: every token's value, how the interface moves and
// feels, and the painters for anything that tokens can't describe. The
// defaults are Quilt's own look; a theme overrides what it changes:
//
//     ThemeSpec {
//         name: "Paper"
//         modes: ThemeSpec.LightOnly
//         accent: "#c2410c"
//         radius: 0
//     }
//
// Apply one with `Theme.spec = mySpec`, and Theme's tokens follow it. Read
// tokens from Theme, never from a spec: an application's overrides live on
// Theme. Colours may depend on `dark`, which Theme sets; a spec never sets
// it. Leave a value marked "derived" undefined to have Theme compute it from
// the other tokens, as Quilt's own look does.
QtObject {
    enum Modes { Both, DarkOnly, LightOnly }
    enum Caret { Line, Bar, Block, Underline }
    enum KnobDrag { Vertical, Either, Rotary }

    // About the theme
    property string name: "Quilt"
    property string description: "Quiet chrome: the interface is the quietest thing on screen, and the user's values are the brightest."
    property string question            // the UX question the theme is there to answer
    property int modes: ThemeSpec.Both
    property var fonts: []              // font files (urls) to load before the theme is used
    property string credits
    property var contrastTargets: ({})  // deliberate exceptions to the contrast checks, by token name

    // Whether the interface is dark. Set by Theme, from Theme.dark.
    property bool dark: true

    // Surfaces, from furthest to nearest
    property color canvas: dark ? "#0e0f12" : "#e4e6ea"
    property color surface: dark ? "#1a1c20" : "#fafafb"
    property color raised: dark ? "#23262b" : "#ffffff"
    property color control: dark ? "#272a30" : "#eceef1"
    property color controlHover: dark ? "#2f3239" : "#e2e5e9"
    property color controlFill: dark ? "#3a3e47" : "#d2d6dc"
    property color border: dark ? "#2d3037" : "#dadde2"
    property color controlBorder: "transparent"
    property color panelOutline: "transparent"  // around each docked panel
    property color shadow: dark ? "transparent" : Qt.rgba(0.1, 0.12, 0.16, 0.12)
    property color well: dark ? "#121316" : "#eef0f3"

    // Text
    property color text: dark ? "#e4e6ea" : "#1b1d21"
    property color textSecondary: dark ? "#9ca1ab" : "#565c66"
    property color textTertiary: dark ? "#787d87" : "#7b818b"

    // Meaning
    property color accent: dark ? "#4c8dff" : "#2a66dd"
    property color accentInk: dark ? "#0e0f12" : "#ffffff"
    property color driven: dark ? "#a98bf5" : "#6f4ad3"
    property color error: dark ? "#f0616d" : "#c92f3a"
    property color warning: dark ? "#e0a53a" : "#946000"
    property color danger: "#e5484d"
    property color dangerInk: "white"

    // Derived: undefined lets Theme compute them
    property var selection              // accent at 18%
    property var textSelection          // accent at 38%
    property var rowHover               // text at 3.5% (4.5% light)
    property var focus                  // the focus ring: accent
    property var fillInk                // text on controlFill (a selected segment, a highlighted item): text

    // Type. Empty families and a zero size follow fontFamily and fontSize.
    property string fontFamily: Application.font.family
    property string fontFamilyTitle     // section titles, tabs, window titles
    property string fontFamilyValue     // numbers and values
    property int fontSize: 12
    property int fontSizeSmall: 11
    property int fontSizeTitle: 0
    property int fontWeight: Font.Normal
    property int fontWeightStrong: Font.Medium
    property int titleCapitalization: Font.MixedCase
    property real titleLetterSpacing: 0
    property int textRenderType: Text.NativeRendering

    // Shape
    property real radius: 8
    property real controlRadius: 4
    property real innerRadius: 3
    property real focusWidth: 1.5
    property real focusOffset: 1        // the ring's distance outside a control
    property real controlBorderWidth: 1 // when controlBorder is set
    property real outlineWidth: 1       // panelOutline, a frameless window's edge

    // Icons
    property real iconStrokeWidth: 1.3
    property int iconCap: ShapePath.RoundCap
    property var icons: ({})            // name → SVG path on the 12-unit grid, replacing Quilt's glyph

    // Feel. Theme.feel can take these from another spec, so a look can be
    // tried with another theme's motion and metrics.
    property int durationFast: 80
    property int duration: 120
    property int durationLayout: 160
    property int easing: Easing.OutCubic

    property real controlHeight: 24
    property real rowHeight: 28
    property real tabHeight: 32
    property real titleBarHeight: 36
    property real gap: 6
    property real panelPadding: 12
    property real gutter: 16
    property real controlPadding: 8
    property real glyphSize: 12

    property bool hoverReveal: true     // dock buttons show on hover only
    property bool hoverFadeIn: false    // hover fades in as well as out
    property real pressTravel: 0        // pixels a pressed button's face moves down
    property int caretStyle: ThemeSpec.Line
    property int knobDrag: ThemeSpec.Vertical
    property bool drawIn: false         // painters may animate in when they first appear
    property var sounds: null           // what Quilt.Themes plays for each Feedback event

    // Painters
    readonly property Skins skins: Skins { }
}
