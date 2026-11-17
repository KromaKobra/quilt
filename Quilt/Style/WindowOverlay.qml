import QtQuick
import QtQuick.Templates as T

// The theme's `overlay` painter, over everything in a window, popups
// included: scanlines, grain, a vignette. It never takes input. Declare
// one in a window that isn't a Quilt ApplicationWindow (which has its own):
//
//     Window { WindowOverlay { } }
Loader {
    parent: T.Overlay.overlay
    anchors.fill: parent
    z: 1e6
    active: Theme.skins.overlay !== null
    enabled: false
    sourceComponent: Surface {
        slot: "overlay"
        color: "transparent"
    }
}
