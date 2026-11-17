pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quilt.Style

// One tab group of a DockArea: a tab bar plus the content host that the
// group's panels are parented into (only the current one is visible). A
// panel that can't share a group (tabbable: false) gets a plain title bar
// instead of tabs.
Item {
    id: stack

    required property string stackId
    required property var area

    readonly property DockStyle style: area.style
    readonly property var manager: area.manager
    readonly property var info: area.stackInfo(stackId, area.revision)
    readonly property string currentId: info ? info.current : ""
    readonly property var currentPanel: manager ? manager.panel(currentId) : null
    readonly property int currentIndex: panelIds.indexOf(currentId)
    readonly property bool maximized: area.maximizedStackId === stackId
    readonly property bool solo: !!currentPanel && !currentPanel.tabbable && panelIds.length === 1
    readonly property var rect: area.geometry.rects[stackId]
    property alias contentHost: host

    // Only reassigned when the set or order of tabs changes, so switching
    // tabs never rebuilds them (and never kills a press in progress).
    property var panelIds: info ? info.panels : []
    onInfoChanged: {
        const ids = info ? info.panels : [];
        if (ids.join("\n") !== panelIds.join("\n"))
            panelIds = ids;
    }
    onCurrentIndexChanged: Qt.callLater(revealCurrent)

    visible: rect !== undefined
    x: rect ? rect.x : 0
    y: rect ? rect.y : 0
    width: rect ? rect.width : 0
    height: rect ? rect.height : 0
    Behavior on x { enabled: stack.area._animate; NumberAnimation { duration: stack.style.animationDuration; easing.type: stack.style.easing } }
    Behavior on y { enabled: stack.area._animate; NumberAnimation { duration: stack.style.animationDuration; easing.type: stack.style.easing } }
    Behavior on width { enabled: stack.area._animate; NumberAnimation { duration: stack.style.animationDuration; easing.type: stack.style.easing } }
    Behavior on height { enabled: stack.area._animate; NumberAnimation { duration: stack.style.animationDuration; easing.type: stack.style.easing } }

    function select(panelId) {
        area.setCurrent(panelId);
    }

    // Insertion index for a drop at x (stack coordinates) over the tab bar.
    function tabIndexAt(x) {
        const cx = x - tabScroll.x + tabScroll.contentX;
        for (let i = 0; i < tabs.count; ++i) {
            const t = tabs.itemAt(i);
            if (t && cx < t.x + t.width / 2)
                return i;
        }
        return tabs.count;
    }

    // x (stack coordinates) of the insertion marker for `index`.
    function tabInsertX(index) {
        if (tabs.count === 0)
            return tabScroll.x;
        const last = index >= tabs.count;
        const t = tabs.itemAt(last ? tabs.count - 1 : Math.max(0, index));
        if (!t)
            return tabScroll.x;
        return tabScroll.x - tabScroll.contentX + (last ? t.x + t.width : t.x);
    }

    function revealCurrent() {
        const t = tabs.itemAt(currentIndex);
        if (!t)
            return;
        if (t.x < tabScroll.contentX)
            tabScroll.contentX = t.x;
        else if (t.x + t.width > tabScroll.contentX + tabScroll.width)
            tabScroll.contentX = t.x + t.width - tabScroll.width;
    }

    // Snapshot the content as the drag image, then run the platform drag.
    function beginTabDrag(p, handler) {
        if (!p || !p.movable || !manager || manager.dragPanel)
            return;
        const scale = Math.min(1, 240 / Math.max(1, host.width), 180 / Math.max(1, host.height));
        const size = Qt.size(Math.max(1, Math.round(host.width * scale)),
                             Math.max(1, Math.round(host.height * scale)));
        const started = host.grabToImage(result => {
            if (handler.active)
                runDrag(p, result.url);
        }, size);
        if (!started)
            runDrag(p, "");
    }

    function runDrag(p, imageUrl) {
        area.startDrag(p, imageUrl, Qt.point(12, 12));
        // The platform drag consumed the release; briefly disable the tab
        // drag handlers so they don't stay stuck in the active state.
        _resetDrag = true;
        _resetDrag = false;
    }

    property bool _resetDrag: false

    // ---------------------------------------------------------------------
    //  Background: the tab strip and the content are one surface, parted by
    //  a hairline.

    Surface {
        id: chrome
        anchors.fill: parent
        slot: "panel"
        radius: stack.style.radius
        fill: stack.currentPanel ? stack.currentPanel.background : stack.style.panel
        header: stack.style.tabHeight
        headerFill: stack.style.tabBar
        edge: Theme.panelOutline                // drawn by a theme's panel painter
        edgeWidth: Theme.outlineWidth
        active: !!stack.manager && !!stack.currentPanel && stack.manager.activePanel === stack.currentPanel
        color: "transparent"                    // drawn by the parts below, or by the painter
        border.width: 0

        Rectangle {
            visible: !chrome.skinned
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: chrome.header
            topLeftRadius: chrome.radius
            topRightRadius: chrome.radius
            color: chrome.headerFill
        }
        Rectangle {
            visible: !chrome.skinned
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: chrome.header; top: parent.top }
            bottomLeftRadius: chrome.radius
            bottomRightRadius: chrome.radius
            color: chrome.fill
        }
        Rectangle {
            visible: !chrome.skinned
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: chrome.header - 1 }
            height: 1
            color: stack.style.border
        }
    }

    // ---------------------------------------------------------------------
    //  Tab strip

    Item {
        id: strip
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: stack.style.tabHeight

        HoverHandler { id: stripHover }

        Flickable {
            id: tabScroll
            anchors { left: parent.left; right: buttons.visible ? buttons.left : parent.right; top: parent.top; leftMargin: 2 }
            height: stack.style.tabHeight       // not anchored: the Row needs it before its first layout
            visible: !stack.solo
            contentWidth: tabRow.width
            contentHeight: height
            interactive: false
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                onWheel: event => {
                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    tabScroll.contentX = Math.max(0, Math.min(tabScroll.contentWidth - tabScroll.width,
                                                              tabScroll.contentX - d / 2));
                }
            }

            Row {
                id: tabRow
                height: tabScroll.height

                Repeater {
                    id: tabs
                    model: stack.panelIds

                    // A tab is its title and nothing else: the current one is
                    // brighter and underlined, in the accent colour when its
                    // panel is the active one.
                    delegate: Item {
                        id: tab
                        required property string modelData
                        readonly property var panel: stack.manager ? stack.manager.panel(modelData) : null
                        readonly property bool current: stack.currentId === modelData
                        readonly property bool active: current && !!stack.manager && stack.manager.activePanel === panel
                        readonly property bool hasIcon: !!panel && panel.icon.toString() !== ""
                        readonly property real inset: 10

                        // Sized for the heavier weight, so selecting a tab never
                        // moves its neighbours.
                        width: Math.min(220, Math.max(40, Math.ceil(measure.implicitWidth) + (hasIcon ? 20 : 0) + 2 * inset))
                        height: tabRow.height

                        Accessible.role: Accessible.PageTab
                        Accessible.name: label.text
                        Accessible.selected: current
                        Accessible.onPressAction: stack.select(modelData)

                        Text {
                            id: measure
                            visible: false
                            text: label.text
                            font.family: stack.style.fontFamily
                            font.pixelSize: stack.style.fontPixelSize
                            font.weight: stack.style.fontWeightStrong
                            font.capitalization: stack.style.capitalization
                            font.letterSpacing: stack.style.letterSpacing
                            renderType: stack.style.textRenderType
                        }

                        Image {
                            id: icon
                            visible: tab.hasIcon
                            source: tab.panel ? tab.panel.icon : ""
                            anchors { left: parent.left; leftMargin: tab.inset; verticalCenter: parent.verticalCenter }
                            width: 14
                            height: 14
                            sourceSize: Qt.size(28, 28)
                            fillMode: Image.PreserveAspectFit
                            opacity: tab.current || tabHover.hovered ? 1 : 0.7
                        }

                        Text {
                            id: label
                            anchors {
                                left: tab.hasIcon ? icon.right : parent.left
                                leftMargin: tab.hasIcon ? 6 : tab.inset
                                right: parent.right
                                rightMargin: tab.inset
                                verticalCenter: parent.verticalCenter
                            }
                            text: tab.panel ? tab.panel.title : tab.modelData
                            elide: Text.ElideRight
                            color: tab.current || tabHover.hovered ? stack.style.text : stack.style.textDim
                            font.family: stack.style.fontFamily
                            font.pixelSize: stack.style.fontPixelSize
                            font.weight: tab.current ? stack.style.fontWeightStrong : stack.style.fontWeight
                            font.capitalization: stack.style.capitalization
                            font.letterSpacing: stack.style.letterSpacing
                            renderType: stack.style.textRenderType
                        }

                        TabFace {
                            anchors.fill: parent
                            current: tab.current
                            active: tab.active
                            hovered: tabHover.hovered
                            inset: tab.inset
                            accent: stack.style.accent
                            faint: stack.style.textFaint
                        }

                        // Shown on hover only. It sits in the space between
                        // tabs, over the end of the title, so no tab changes
                        // width when it appears.
                        IconButton {
                            id: closeButton
                            style: stack.style
                            glyph: "close"
                            tip: qsTr("Close")
                            size: 16
                            backdrop: stack.style.tabBar
                            visible: !!tab.panel && tab.panel.closable && tabHover.hovered
                            anchors { right: parent.right; rightMargin: -4; verticalCenter: parent.verticalCenter }
                            onClicked: tab.panel.close()
                        }

                        HoverHandler { id: tabHover }

                        TapHandler {
                            gesturePolicy: TapHandler.DragThreshold
                            onPressedChanged: if (pressed) stack.select(tab.modelData)
                            onDoubleTapped: stack.manager.toggleMaximized(tab.modelData)
                        }

                        TapHandler {
                            acceptedButtons: Qt.MiddleButton
                            onTapped: if (tab.panel && tab.panel.closable) tab.panel.close()
                        }

                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: (eventPoint) => {
                                stack.select(tab.modelData);
                                stack.openTabMenu(tab.modelData, tab, eventPoint.position);
                            }
                        }

                        DragHandler {
                            id: tabDrag
                            target: null
                            enabled: !!tab.panel && tab.panel.movable && !stack._resetDrag
                            onActiveChanged: if (active) stack.beginTabDrag(tab.panel, tabDrag)
                        }
                    }
                }
            }
        }

        // Title bar of a solo (non-tabbable) panel: same gestures as a tab,
        // but there is nothing to select, so no underline.
        Item {
            id: titleBar
            anchors { left: parent.left; right: buttons.visible ? buttons.left : parent.right; top: parent.top; bottom: parent.bottom }
            visible: stack.solo
            readonly property bool hasIcon: !!stack.currentPanel && stack.currentPanel.icon.toString() !== ""

            Image {
                id: titleIcon
                visible: titleBar.hasIcon
                source: stack.currentPanel ? stack.currentPanel.icon : ""
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 14
                height: 14
                sourceSize: Qt.size(28, 28)
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors {
                    left: titleBar.hasIcon ? titleIcon.right : parent.left
                    leftMargin: titleBar.hasIcon ? 6 : 12
                    right: parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                text: stack.currentPanel ? stack.currentPanel.title : ""
                elide: Text.ElideRight
                color: stack.style.textDim
                font.family: stack.style.fontFamily
                font.pixelSize: stack.style.fontPixelSize
                renderType: stack.style.textRenderType
            }

            TapHandler {
                gesturePolicy: TapHandler.DragThreshold
                onPressedChanged: if (pressed) stack.select(stack.currentId)
                onDoubleTapped: stack.manager.toggleMaximized(stack.currentId)
            }

            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: if (stack.currentPanel.closable) stack.currentPanel.close()
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: (eventPoint) => {
                    stack.openTabMenu(stack.currentId, titleBar, eventPoint.position);
                }
            }

            DragHandler {
                id: titleDrag
                target: null
                enabled: stack.solo && stack.currentPanel.movable && !stack._resetDrag
                onActiveChanged: if (active) stack.beginTabDrag(stack.currentPanel, titleDrag)
            }
        }

        // Rare actions: shown while the pointer is over this strip (or always,
        // with style.buttonsOnHover off). The tab menu and double-click do the
        // same things without them. Their room is always kept, so tabs don't
        // move when they appear.
        Row {
            id: buttons
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 2
            visible: stack.width >= 150         // narrow stacks give the room to their tabs
            opacity: !stack.style.buttonsOnHover || stripHover.hovered || stack.maximized ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

            IconButton {
                style: stack.style
                glyph: "popout"
                tip: qsTr("Pop out into a new window")
                visible: !!stack.currentPanel && !!stack.manager && stack.manager.canFloat(stack.currentPanel)
                         && (stack.area.isMain || stack.area.panelCount > 1)
                onClicked: stack.manager.popOut(stack.currentId)
            }
            IconButton {
                style: stack.style
                glyph: stack.maximized ? "restore" : "maximize"
                tip: stack.maximized ? qsTr("Restore") : qsTr("Maximize")
                visible: stack.maximized || stack.area.stackCount > 1
                onClicked: stack.manager.toggleMaximized(stack.currentId)
            }
            IconButton {
                style: stack.style
                glyph: "close"
                tip: qsTr("Close")
                visible: stack.solo && stack.currentPanel.closable
                onClicked: stack.currentPanel.close()
            }
        }
    }

    // ---------------------------------------------------------------------
    //  Content

    Item {
        id: host
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: strip.bottom }
        clip: true
    }

    // Panel content is clipped to a rectangle. These two pieces, in the
    // colour behind the panels, round off its bottom corners. They are not
    // drawn when that colour is see-through.
    Repeater {
        model: stack.style.radius > 0 && stack.style.background.a === 1 ? 2 : 0
        delegate: Shape {
            id: cap
            required property int index
            readonly property real r: stack.style.radius
            x: index === 0 ? 0 : stack.width - r
            y: stack.height - r
            width: r
            height: r
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { origin.x: cap.r / 2; xScale: cap.index === 0 ? 1 : -1 }
            ShapePath {
                strokeWidth: -1
                fillColor: stack.style.background
                startX: 0
                startY: 0
                PathArc { x: cap.r; y: cap.r; radiusX: cap.r; radiusY: cap.r; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: cap.r }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // Observes presses on the content to track the active panel. A
    // PointHandler only takes passive grabs, so the content still gets every
    // event (a TapHandler here would swallow clicks).
    Item {
        anchors.fill: host
        PointHandler {
            acceptedButtons: Qt.AllButtons
            onActiveChanged: {
                if (active && stack.currentPanel && stack.manager)
                    stack.manager.activePanel = stack.currentPanel;
            }
        }
    }

    // The tab's context menu, made the first time it is asked for: most tab
    // groups never need one.
    property Menu _tabMenu: null
    function openTabMenu(panelId: string, item: Item, at: point) {
        if (!_tabMenu)
            _tabMenu = tabMenuComponent.createObject(stack) as Menu;
        (_tabMenu as TabMenu).panelId = panelId;
        _tabMenu.popup(item, at.x, at.y);
    }

    Component { id: tabMenuComponent; TabMenu { } }

    component TabMenu: Menu {
        id: tabMenu
        property string panelId
        readonly property var panel: stack.manager ? stack.manager.panel(panelId) : null

        MenuItem {
            text: qsTr("Pop Out")
            enabled: !!tabMenu.panel && !!stack.manager && stack.manager.canFloat(tabMenu.panel)
                     && (stack.area.isMain || stack.area.panelCount > 1)
            onTriggered: stack.manager.popOut(tabMenu.panelId)
        }
        MenuItem {
            text: stack.maximized ? qsTr("Restore") : qsTr("Maximize")
            enabled: stack.maximized || stack.area.stackCount > 1
            onTriggered: stack.manager.toggleMaximized(tabMenu.panelId)
        }
        MenuSeparator { }
        MenuItem {
            text: qsTr("Close")
            enabled: !!tabMenu.panel && tabMenu.panel.closable
            onTriggered: stack.manager.closePanel(tabMenu.panelId)
        }
    }

    component IconButton: Item {
        id: button
        required property DockStyle style
        property string glyph                  // an Icon name: close | popout | maximize | restore
        property string tip
        property real size: 20
        property color backdrop: "transparent"  // hides what the button sits over
        readonly property bool skinned: Theme.skins.button !== null
        signal clicked()

        width: size
        height: size

        Accessible.role: Accessible.Button
        Accessible.name: tip
        Accessible.onPressAction: clicked()

        Rectangle {
            anchors.fill: parent
            radius: Theme.controlRadius
            color: button.skinned ? "transparent" : button.backdrop
        }
        Face {
            anchors.fill: parent
            role: Face.Tool
            hovered: hover.hovered
            pressed: tap.pressed
            color: button.skinned ? "transparent" : button.style.tabHover
            visible: hover.hovered
        }

        Icon {
            anchors.centerIn: parent
            name: button.glyph
            size: 12
            color: hover.hovered ? button.style.text : button.style.textDim
        }

        HoverHandler { id: hover }
        TapHandler { id: tap; onTapped: button.clicked() }
        Tip { text: button.tip; shown: hover.hovered; pressed: tap.pressed }
    }
}
