pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import Quilt.Style

// An expandable heading that groups rows.
//
//     Section {
//         title: "Transform"
//         PropertyRow { label: "Position"; VectorField { … } }
//         PropertyRow { label: "Rotation"; NumberField { … } }
//     }
//
// The whole header toggles it (Ctrl+click toggles every section alongside
// it). Collapsed, it shows a dot if a row inside differs from its default.
// Give it a `key` and it remembers open or closed between runs.
Item {
    id: section

    property string title
    property bool expanded: true
    property string key                     // remember `expanded` under this name (uses QtCore Settings)
    default property alias content: body.data
    property alias accessory: accessorySlot.data   // items at the right of the header, e.g. a Switch
    property bool contentEnabled: true      // false dims the rows and blocks input (a switched-off feature)
    property bool divider: true             // the hairline beneath

    readonly property bool hasModified: _modifiedRows > 0
    readonly property bool isQuiltSection: true

    property int _modifiedRows: 0
    property int _matchingRows: 0
    property var _inspector: null
    property var _settings: null
    property bool _animate: false
    readonly property bool _filtering: !!_inspector && _inspector.filter !== ""
    readonly property bool _open: expanded || _filtering

    function toggle() {
        _animate = true;                        // only a toggle slides; rows arriving at start-up don't
        expanded = !expanded;
        _animate = false;
    }

    function _findInspector() {
        let found = null;
        for (let p = section.parent; p; p = p.parent) {
            if (p["isQuiltInspector"] === true) {
                found = p;
                break;
            }
        }
        _inspector = found;
    }

    // Opens or closes every section next to this one, to match it.
    function _toggleAll() {
        const to = !expanded;
        const siblings = parent ? parent.children : [];
        for (let i = 0; i < siblings.length; ++i)
            if (siblings[i]["isQuiltSection"] === true)
                siblings[i]["expanded"] = to;
    }

    function _store() {
        if (!_settings)
            _settings = settingsComponent.createObject(section);
        return _settings;
    }

    visible: !_filtering || _matchingRows > 0
    implicitWidth: 240
    implicitHeight: header.height + clipper.height + (divider ? 13 : 0)
    width: parent ? parent.width : implicitWidth
    height: visible ? implicitHeight : 0

    onParentChanged: _findInspector()
    Component.onCompleted: {
        _findInspector();
        if (key !== "") {
            const saved = _store().value(key);
            if (saved !== undefined)
                expanded = saved === true || saved === "true";
        }
    }
    onExpandedChanged: if (key !== "") _store().setValue(key, expanded)

    Component {
        id: settingsComponent
        Settings { category: "QuiltSections" }
    }

    Item {
        id: header
        objectName: "header"
        width: parent.width
        height: Theme.rowHeight
        activeFocusOnTab: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                section.toggle();
            else if (event.key === Qt.Key_Right)
                section.expanded = true;
            else if (event.key === Qt.Key_Left)
                section.expanded = false;
            else
                return;
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.rowHover
            visible: headerHover.hovered || header.activeFocus
        }
        Rectangle {
            anchors { fill: parent; margins: 1 }
            color: "transparent"
            radius: Theme.controlRadius
            border.width: Theme.focusWidth
            border.pixelAligned: false
            border.color: Theme.accent
            visible: header.activeFocus          // only Tab gives the header focus
        }

        HoverHandler { id: headerHover }
        TapHandler {
            acceptedModifiers: Qt.NoModifier
            onTapped: section.toggle()
        }
        TapHandler {
            acceptedModifiers: Qt.ControlModifier
            onTapped: section._toggleAll()
        }

        Icon {
            x: Theme.gutter - 4
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-down"
            size: 10
            rotation: section._open ? 0 : -90
            Behavior on rotation { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Text {
            id: titleText
            x: Theme.gutter + 14
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - x - accessorySlot.width - Theme.panelPadding - 16)
            text: section.title
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Theme.fontWeightStrong
            renderType: Theme.textRenderType
        }

        // Something in here was changed, even though it can't be seen.
        Rectangle {
            anchors { left: titleText.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
            width: 5
            height: 5
            radius: 2.5
            color: Theme.accent
            visible: section.hasModified && !section._open
        }

        Row {
            id: accessorySlot
            anchors { right: parent.right; rightMargin: Theme.panelPadding; verticalCenter: parent.verticalCenter }
            spacing: 4
        }
    }

    Item {
        id: clipper
        y: header.height
        width: parent.width
        height: section._open ? body.implicitHeight : 0
        clip: true

        // Small sections slide; a long one sliding open costs more than it explains.
        Behavior on height {
            enabled: section._animate && body.implicitHeight < 420 && Theme.duration > 0
            NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic }
        }

        Column {
            id: body
            width: parent.width
            visible: section._open || clipper.height > 0    // still drawn while sliding shut
            enabled: section.contentEnabled
            opacity: section.contentEnabled ? 1 : 0.45
        }
    }

    Rectangle {
        visible: section.divider
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
        height: 1
        color: Theme.border
    }
}
