pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T

// A dropdown or context menu. Fill it with Actions, MenuItems,
// MenuSeparators and nested Menus, as with Qt's Menu:
//
//     Menu {
//         Action { text: "Reset"; shortcut: "Ctrl+R"; onTriggered: reset() }
//         MenuSeparator { }
//         Menu { title: "More"; Action { text: "…" } }
//     }
T.Menu {
    id: control

    property real _itemWidth: 0

    // Size to the widest row, and line the labels up when any row has a tick.
    function _measure() {
        let widest = 0, ticks = false;
        for (let i = 0; i < count; ++i) {
            const item = itemAt(i) as MenuItem;
            if (item && item.checkable)
                ticks = true;
        }
        for (let i = 0; i < count; ++i) {
            const item = itemAt(i);
            if (!item)
                continue;
            const row = item as MenuItem;
            if (row)
                row.leadingWidth = ticks ? 18 : 0;
            widest = Math.max(widest, item.implicitWidth);
        }
        _itemWidth = widest;
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, contentHeight + topPadding + bottomPadding)

    margins: 4
    padding: 4
    overlap: 4
    popupType: Theme.popupType

    onAboutToShow: _measure()

    delegate: MenuItem { }

    contentItem: ListView {
        implicitWidth: control._itemWidth
        implicitHeight: contentHeight
        model: control.contentModel
        interactive: Window.window
                     ? contentHeight + control.topPadding + control.bottomPadding > control.height
                     : false
        clip: true
        currentIndex: control.currentIndex
        boundsBehavior: Flickable.StopAtBounds
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast } }

    background: PopupBackground {
        implicitWidth: 160
        implicitHeight: 8
    }

    T.Overlay.modal: Rectangle { color: Theme.alpha(Theme.canvas, 0.5) }
    T.Overlay.modeless: Item { }
}
