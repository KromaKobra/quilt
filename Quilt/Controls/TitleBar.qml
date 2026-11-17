pragma ComponentBehavior: Bound
import QtQuick
import Quilt.Style

// A window's top bar: dropdown menus, the title, and the window buttons.
//
//     ApplicationWindow {
//         frameless: true                 // TitleBar replaces the system's title bar
//         menuBar: TitleBar {
//             Menu { title: "File"; Action { text: "Open…"; onTriggered: … } }
//             Menu { title: "Edit"; … }
//         }
//     }
//
// It works in any window, as its `menuBar` or `header`. Drag it to move the
// window and double-click it to maximize. In a frameless window it also
// draws minimize, maximize and close, and lets the window be resized from
// its edges. With the system's title bar left on, it is simply a menu bar
// (and shows no title, unless you give it one).
Item {
    id: bar

    default property alias menus: menuBar.contentData
    property string title: frameless ? window.title : ""    // with the system's title bar, that shows it
    property url icon                           // a small image at the far left
    property alias leading: leadingSlot.data    // your items after the menus
    property alias trailing: trailingSlot.data  // your items before the window buttons
    property color color: Theme.canvas
    property bool windowButtons: frameless
    property bool buttonsOnLeft: Qt.platform.os === "osx"
    property real resizeMargin: 5               // how far in from the edge a frameless window resizes

    readonly property var window: Window.window
    readonly property bool frameless: !!window && (window.flags & Qt.FramelessWindowHint) !== 0
    readonly property bool maximized: !!window && (window.visibility === Window.Maximized
                                                   || window.visibility === Window.FullScreen)

    function toggleMaximized() {
        if (!window)
            return;
        if (maximized)
            window.showNormal();
        else
            window.showMaximized();
    }

    implicitWidth: leftSide.width + rightSide.width + 120
    implicitHeight: Theme.titleBarHeight

    Surface {
        anchors.fill: parent
        slot: "bar"
        fill: bar.color
        active: !!bar.window && bar.window.active
    }

    // The bar itself: drag to move, double-click to maximize.
    Item {
        anchors.fill: parent
        TapHandler {
            onDoubleTapped: bar.toggleMaximized()
        }
        DragHandler {
            target: null
            onActiveChanged: if (active && bar.window) bar.window.startSystemMove()
        }
    }

    Text {
        id: titleText
        // Centred in the window when there is room, otherwise between the two sides.
        readonly property real room: rightSide.x - leftSide.width - 24
        readonly property real centred: (bar.width - width) / 2
        x: Math.round(Math.max(leftSide.width + 12, Math.min(centred, rightSide.x - width - 12)))
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(implicitWidth, room))
        visible: room > 40
        text: bar.title
        elide: Text.ElideRight
        color: bar.window && bar.window.active ? Theme.textSecondary : Theme.textTertiary
        font.family: Theme.fontFamilyTitle
        font.pixelSize: Theme.fontSize
        font.capitalization: Theme.titleCapitalization
        font.letterSpacing: Theme.titleLetterSpacing
        renderType: Theme.textRenderType
    }

    Row {
        id: leftSide
        anchors.verticalCenter: parent.verticalCenter
        x: bar.buttonsOnLeft && buttons.visible ? buttons.width + 4 : 6
        spacing: 2

        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.icon.toString() !== ""
            source: bar.icon
            width: 16
            height: 16
            sourceSize: Qt.size(32, 32)
            fillMode: Image.PreserveAspectFit
        }
        Item {
            width: 6
            height: 1
            visible: bar.icon.toString() !== ""
        }
        MenuBar {
            id: menuBar
            anchors.verticalCenter: parent.verticalCenter
        }
        Row {
            id: leadingSlot
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
        }
    }

    Row {
        id: rightSide
        anchors.verticalCenter: parent.verticalCenter
        x: bar.width - width - (!bar.buttonsOnLeft && buttons.visible ? buttons.width : 6)
        Row {
            id: trailingSlot
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            rightPadding: 6
        }
    }

    // Minimize, maximize, close. Each fills the bar's height and the last
    // reaches the window's corner, so they are easy to hit.
    Row {
        id: buttons
        objectName: "windowButtons"
        visible: bar.windowButtons
        height: parent.height
        x: bar.buttonsOnLeft ? 0 : bar.width - width
        layoutDirection: bar.buttonsOnLeft ? Qt.RightToLeft : Qt.LeftToRight

        WindowButton {
            glyph: "minimize"
            tip: qsTr("Minimize")
            onClicked: bar.window.showMinimized()
        }
        WindowButton {
            glyph: bar.maximized ? "restore" : "maximize"
            tip: bar.maximized ? qsTr("Restore") : qsTr("Maximize")
            onClicked: bar.toggleMaximized()
        }
        WindowButton {
            glyph: "close"
            tip: qsTr("Close")
            danger: true
            onClicked: bar.window.close()
        }
    }

    component WindowButton: Item {
        id: button
        property string glyph
        property string tip
        property bool danger: false
        signal clicked()

        width: 44
        height: parent.height

        Accessible.role: Accessible.Button
        Accessible.name: tip
        Accessible.onPressAction: clicked()

        Face {
            anchors.fill: parent
            role: Face.Tool
            radius: 0
            hovered: buttonHover.hovered
            danger: button.danger
            opacity: tap.pressed ? 0.8 : 1
            visible: buttonHover.hovered
        }
        Icon {
            anchors.centerIn: parent
            name: button.glyph
            size: 10
            strokeWidth: 1.2
            color: buttonHover.hovered ? (button.danger ? Theme.dangerInk : Theme.text) : Theme.textSecondary
        }
        HoverHandler { id: buttonHover }
        TapHandler {
            id: tap
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: button.clicked()
        }
        Tip { text: button.tip; shown: buttonHover.hovered; pressed: tap.pressed }
    }

    // A frameless window has no system border to resize by. These sit over
    // the window's edges and hand the drag to the system.
    Item {
        id: frame
        objectName: "resizeFrame"
        parent: bar.Window.contentItem
        anchors.fill: parent
        z: 100000
        visible: bar.frameless && !bar.maximized

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Theme.border
        }

        component Grip: MouseArea {
            required property int edges
            acceptedButtons: Qt.LeftButton
            cursorShape: edges === (Qt.LeftEdge | Qt.TopEdge) || edges === (Qt.RightEdge | Qt.BottomEdge) ? Qt.SizeFDiagCursor
                       : edges === (Qt.RightEdge | Qt.TopEdge) || edges === (Qt.LeftEdge | Qt.BottomEdge) ? Qt.SizeBDiagCursor
                       : edges === Qt.LeftEdge || edges === Qt.RightEdge ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onPressed: bar.window.startSystemResize(edges)
        }

        readonly property real m: bar.resizeMargin
        readonly property real c: bar.resizeMargin * 2.4   // corners reach further along each edge

        Grip { edges: Qt.TopEdge; x: frame.c; width: frame.width - 2 * frame.c; height: frame.m }
        Grip { edges: Qt.BottomEdge; x: frame.c; y: frame.height - frame.m; width: frame.width - 2 * frame.c; height: frame.m }
        Grip { edges: Qt.LeftEdge; y: frame.c; width: frame.m; height: frame.height - 2 * frame.c }
        Grip { edges: Qt.RightEdge; x: frame.width - frame.m; y: frame.c; width: frame.m; height: frame.height - 2 * frame.c }
        Grip { edges: Qt.LeftEdge | Qt.TopEdge; width: frame.c; height: frame.c }
        Grip { edges: Qt.RightEdge | Qt.TopEdge; x: frame.width - frame.c; width: frame.c; height: frame.c }
        Grip { edges: Qt.LeftEdge | Qt.BottomEdge; y: frame.height - frame.c; width: frame.c; height: frame.c }
        Grip { edges: Qt.RightEdge | Qt.BottomEdge; x: frame.width - frame.c; y: frame.height - frame.c; width: frame.c; height: frame.c }
    }
}
