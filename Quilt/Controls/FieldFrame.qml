import QtQuick
import Quilt.Style

// The background of a field: a flat fill, a ring for focus or an error,
// and a brief flash (flash()) for when Quilt corrected what the user
// entered. A theme draws it with its `field` painter.
Face {
    id: frame

    role: Face.Field
    focusRing: true

    // Hover arrives at once and leaves softly.
    Behavior on color {
        enabled: !frame.hovered && !frame.skinned && Theme.durationFast > 0
        ColorAnimation { duration: Theme.durationFast }
    }
}
