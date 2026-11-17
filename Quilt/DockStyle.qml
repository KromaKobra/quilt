import QtQuick
import Quilt.Style

// Colours and metrics for every DockArea in one docking system. The defaults
// come from Theme (Quilt.Style), so docking matches Quilt's controls and
// follows Theme.dark. Override individual values on the main area, e.g.
// `style.accent: "#ff8a3d"`, or assign a whole DockStyle { }. Pop-out
// windows share the main area's style.
QtObject {
    // Surfaces
    property color background: Theme.canvas     // behind the panels, visible in the gaps
    property color panel: Theme.surface         // default DockPanel.background
    property color tabBar: panel                // the tab strip; one surface with the panel by default
    property color tabHover: Theme.controlHover // behind a hovered tab-strip button
    property color border: Theme.border         // the hairline under the tab strip

    // Text and highlights
    property color text: Theme.text             // the current tab
    property color textDim: Theme.textSecondary // other tabs, glyphs
    property color textFaint: Theme.textTertiary    // the current-tab underline of an inactive panel
    property color accent: Theme.accent         // the active panel's underline, drop preview, split lines
    property color dropFill: Qt.rgba(accent.r, accent.g, accent.b, 0.16)

    // Metrics
    property real gap: Theme.gap                // space between panels (0 for a seamless look)
    property real radius: Theme.radius          // corner radius of each panel
    property real tabHeight: Theme.tabHeight
    property real handleGrabSize: 8             // grab width of split handles, even when gap is 0
    property real snapDistance: 10              // a dragged split line snaps onto one this close
    property real dropIndicatorSize: 36         // the "dock at full edge" squares shown while dragging
    property string fontFamily: Theme.fontFamilyTitle      // tab titles
    property int fontPixelSize: Theme.fontSize
    property int fontWeight: Theme.fontWeight              // other tabs
    property int fontWeightStrong: Theme.fontWeightStrong  // the current tab
    property int capitalization: Theme.titleCapitalization
    property real letterSpacing: Theme.titleLetterSpacing
    property int textRenderType: Theme.textRenderType
    property int animationDuration: Theme.durationLayout    // 0 disables layout animations
    property int easing: Theme.easing

    // Pop-out, maximize and close buttons appear when the pointer is over
    // their tab strip. Set false to show them all the time. The theme
    // decides by default.
    property bool buttonsOnHover: Theme.hoverReveal
}
