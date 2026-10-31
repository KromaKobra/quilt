import QtQuick

// The draggable boundary between two neighbours of a split. It only changes
// those two neighbours and stops at their minimum/maximum sizes.
Item {
    id: handle

    required property string key                // "splitId:index"
    required property var area

    readonly property var info: area.geometry.handles[key]
    readonly property bool horizontal: info ? info.horizontal : true
    readonly property real thickness: Math.max(area.style.handleGrabSize,
                                               info ? (horizontal ? info.width : info.height) : 0)

    visible: info !== undefined
    x: !info ? 0 : horizontal ? info.x + (info.width - thickness) / 2 : info.x
    y: !info ? 0 : horizontal ? info.y : info.y + (info.height - thickness) / 2
    width: !info ? 0 : horizontal ? thickness : info.width
    height: !info ? 0 : horizontal ? info.height : thickness

    Rectangle {
        anchors.centerIn: parent
        width: handle.horizontal ? 2 : parent.width
        height: handle.horizontal ? parent.height : 2
        radius: 1
        color: handle.area.style.accent
        opacity: drag.active ? 0.9 : (hover.hovered ? 0.45 : 0)
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    HoverHandler {
        id: hover
        cursorShape: handle.horizontal ? Qt.SplitHCursor : Qt.SplitVCursor
    }

    DragHandler {
        id: drag
        target: null
        cursorShape: handle.horizontal ? Qt.SplitHCursor : Qt.SplitVCursor
        xAxis.enabled: handle.horizontal
        yAxis.enabled: !handle.horizontal
        onActiveChanged: {
            if (active)
                handle.area.beginResize(handle.key);
            else
                handle.area.endResize();
        }
        onActiveTranslationChanged: {
            if (active)
                handle.area.resize(handle.horizontal ? activeTranslation.x : activeTranslation.y);
        }
    }
}
