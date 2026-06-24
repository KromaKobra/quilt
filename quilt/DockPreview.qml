import QtQuick
import QtQuick.Shapes

/*!
    \qmltype DockPreview
    \inqmlmodule Quilt
    \brief Animated ghost overlay showing where a dragged panel will land.

    DockContainer positions and sizes this preview to mirror the geometry the
    dragged panel will occupy at the current \c hoveredSlotId / \c
    hoveredDropTarget. It paints a low-opacity accent fill with a dashed accent
    border, and animates all four geometry properties so it snaps smoothly as
    the user moves between slots and drop targets. The surrounding docked panels
    animate to make room in concert (see the "make room" inset in \l DockSlot),
    so the layout settles into its post-drop shape while the drag is still in
    flight rather than only on release.
*/
Item {
    id: preview

    Behavior on x      { NumberAnimation { duration: DockManager.previewDuration; easing.type: Easing.OutCubic } }
    Behavior on y      { NumberAnimation { duration: DockManager.previewDuration; easing.type: Easing.OutCubic } }
    Behavior on width  { NumberAnimation { duration: DockManager.previewDuration; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: DockManager.previewDuration; easing.type: Easing.OutCubic } }

    // Low-opacity fill.
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: DockManager.accentColor
        opacity: 0.16
    }

    // Dashed accent border.
    Shape {
        anchors.fill: parent
        anchors.margins: 1.5
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: DockManager.accentColor
            strokeWidth: 2
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [6, 4]
            startX: 0; startY: 0
            PathLine { x: preview.width - 3; y: 0 }
            PathLine { x: preview.width - 3; y: preview.height - 3 }
            PathLine { x: 0; y: preview.height - 3 }
            PathLine { x: 0; y: 0 }
        }
    }
}
