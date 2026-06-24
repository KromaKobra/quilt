import QtQuick

/*!
    \qmltype FloatingPanel
    \inqmlmodule Quilt
    \brief A free-floating positioner that hosts a \l Panel above the dock area.

    FloatingPanel anchors a Panel to the DockContainer at the model's
    \c floatX / \c floatY, sized to \c floatWidth / \c floatHeight, and keeps it
    clamped inside the container. The header drag (handled by Panel, which
    switches behaviour on \c isFloating) moves the panel and can drop it onto a
    dock zone; Panel's edge handles resize it. A soft drop shadow lifts it off
    the dock surface. Geometry transitions animate, except while the panel is
    actively being dragged so it tracks the cursor.
*/
Item {
    id: floatingPanel

    /*! \brief The floating PanelModel rendered here. */
    required property var panelModel

    readonly property bool dragging:
        panelModel && DockManager.activeDragPanelId === panelModel.panelId

    z: 1000
    visible: panelModel && panelModel.isFloating && panelModel.isVisible

    width: panelModel ? panelModel.floatWidth : 200
    height: panelModel ? panelModel.floatHeight : 150
    x: !panelModel ? 0 : Math.max(0, Math.min((parent ? parent.width : width) - width, panelModel.floatX))
    y: !panelModel ? 0 : Math.max(0, Math.min((parent ? parent.height : height) - height, panelModel.floatY))

    Behavior on x      { enabled: !floatingPanel.dragging; NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
    Behavior on y      { enabled: !floatingPanel.dragging; NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
    Behavior on width  { enabled: !floatingPanel.dragging; NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: !floatingPanel.dragging; NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }

    // Soft drop shadow (dependency-free: a blurred-look stack of faint rects).
    Rectangle {
        anchors.fill: panelHost
        anchors.margins: -6
        anchors.topMargin: -2
        anchors.bottomMargin: -10
        radius: (floatingPanel.panelModel ? floatingPanel.panelModel.cornerRadius : 8) + 6
        color: "#000000"
        opacity: 0.28
        z: -1
    }

    Item {
        id: panelHost
        anchors.fill: parent

        Panel {
            anchors.fill: parent
            panelModel: floatingPanel.panelModel
            // A floating panel has no docked neighbours: all edges are open.
            edges: ({ "top": true, "bottom": true, "left": true, "right": true })
        }
    }
}
