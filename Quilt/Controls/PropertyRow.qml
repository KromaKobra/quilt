pragma ComponentBehavior: Bound
import QtQuick
import Quilt.Style

// One row of an inspector: a label and a control.
//
//     PropertyRow { label: "Opacity"; NumberField { … } }
//
// The label is part of the control: clicking it does the control's main
// action, and dragging it scrubs a number. The dot left of the label marks
// a value that differs from its default; clicking the dot resets it.
// Right-click anywhere on the row for reset, copy, paste and linking.
//
// Any item can be the control. To take part in these features it offers
// what it can of: modified, reset(), activate(), copyText(), pasteText(text).
Item {
    id: row

    property string label
    property string description             // tooltip on the label
    default property alias content: slot.data
    property var fill                       // stretch the control? Default: the control's `fillsRow`
    property var menu: []                   // extra row-menu entries: { text, enabled, triggered() }

    // The control: the first item put in the row (through a Loader, the item it loaded).
    readonly property Item control: {
        const first = slot.children.length > 0 ? slot.children[0] : null;
        return first instanceof Loader ? first.item : first;
    }
    readonly property bool modified: !!control && control.modified === true
    readonly property bool stacked: !!inspector && inspector.stacked

    // Found by walking up the item tree; null when the row is used alone.
    property var inspector: null
    property var section: null

    readonly property var _ctl: control       // untyped, for the optional members
    readonly property var _param: _ctl && _ctl.param ? _ctl.param : null
    readonly property int _state: _param && _param.state !== undefined ? _param.state
                                  : (_ctl && _ctl.paramState !== undefined ? _ctl.paramState : Param.Normal)
    readonly property bool _canLink: _param ? typeof _param.setExpression === "function"
                                            : !!_ctl && _ctl.acceptsExpressions === true
    readonly property bool _fill: fill !== undefined ? !!fill : (!!_ctl && _ctl.fillsRow === true)
    readonly property real _labelWidth: inspector ? inspector.labelWidth : 96
    readonly property bool _matches: !inspector || inspector.filter === ""
                                     || label.toLowerCase().indexOf(inspector.filter.toLowerCase()) >= 0
    property bool _counted: false           // this row is in its section's "modified" tally
    property bool _listed: false            // …and in its "matches the filter" tally

    function _marked(item: var, marker: string): bool { return item[marker] === true; }

    function _findAncestors() {
        let found = null, sec = null;
        for (let p = row.parent; p; p = p.parent) {
            if (!sec && _marked(p, "isQuiltSection"))
                sec = p;
            if (_marked(p, "isQuiltInspector")) {
                found = p;
                break;
            }
        }
        if (section !== sec) {
            _tally(false, false);
            section = sec;
        }
        inspector = found;
        _tally(modified, _matches);
    }

    // Keeps the section's counts of modified and filter-matching rows.
    function _tally(isModified: bool, isListed: bool) {
        if (section && _counted !== isModified)
            section._modifiedRows += isModified ? 1 : -1;
        if (section && _listed !== isListed)
            section._matchingRows += isListed ? 1 : -1;
        _counted = isModified && !!section;
        _listed = isListed && !!section;
    }

    function _openMenu(x: real, y: real) {
        if (!control)
            return;
        menuLoader.active = true;
        (menuLoader.item as Menu).popup(row, x, y);
    }

    visible: _matches
    implicitWidth: 240
    implicitHeight: (stacked ? 20 : 0) + Math.max(Theme.controlHeight, control ? control.implicitHeight : 0) + 4
    width: parent ? parent.width : implicitWidth
    height: visible ? implicitHeight : 0

    // The Menu key, pressed in the row's control, opens the row menu.
    Keys.onMenuPressed: _openMenu(Theme.gutter + _labelWidth, height)

    // The label is the control's accessible name, unless it was given one.
    property string _named
    function _nameControl() {
        const item = row._ctl;
        if (!item || label === "" || (item.Accessible.name !== "" && item.Accessible.name !== _named))
            return;
        item.Accessible.name = label;
        _named = label;
    }
    onControlChanged: _nameControl()
    onLabelChanged: _nameControl()

    onParentChanged: _findAncestors()
    Component.onCompleted: {
        _findAncestors();
        _nameControl();
    }
    Component.onDestruction: _tally(false, false)
    onModifiedChanged: _tally(modified, _matches)
    on_MatchesChanged: _tally(modified, _matches)

    // A faint tint ties the label to its value across the gap.
    Rectangle {
        anchors.fill: parent
        color: Theme.rowHover
        visible: rowHover.hovered
    }
    HoverHandler { id: rowHover }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: eventPoint => row._openMenu(eventPoint.position.x, eventPoint.position.y)
    }

    // The modified dot. Under the pointer it becomes a reset arrow.
    MouseArea {
        id: dot
        x: 2
        y: row.stacked ? 3 : Math.round((Math.min(row.height, Theme.rowHeight) - height) / 2)
        width: 14
        height: 14
        visible: row.modified
        hoverEnabled: true
        onClicked: row._ctl.reset()

        Rectangle {
            anchors.centerIn: parent
            width: 5
            height: 5
            radius: 2.5
            color: Theme.accent
            visible: !dot.containsMouse
        }
        Icon {
            anchors.centerIn: parent
            name: "reset"
            size: 10
            color: Theme.accent
            visible: dot.containsMouse
        }
        Tip { text: qsTr("Reset to default"); shown: dot.containsMouse; pressed: dot.pressed }
    }

    MouseArea {
        id: labelArea
        x: Theme.gutter
        y: row.stacked ? 2 : 0
        width: row.stacked ? row.width - Theme.gutter - Theme.panelPadding : row._labelWidth - 8
        height: row.stacked ? 18 : Math.min(row.height, Theme.rowHeight)   // beside the first line of a tall control
        hoverEnabled: true
        preventStealing: scrubbing
        cursorShape: canScrub ? Qt.SizeHorCursor : Qt.ArrowCursor

        readonly property bool canScrub: !!row._ctl && row._ctl.canScrub === true
        property bool scrubbing: false
        property bool decided: false
        property real pressX: 0
        property real pressY: 0
        property real lastX: 0

        onPressed: event => {
            pressX = lastX = event.x;
            pressY = event.y;
            decided = false;
        }
        onPositionChanged: event => {
            if (!pressed)
                return;
            if (scrubbing) {
                row._ctl.scrubBy(event.x - lastX, event.modifiers);
                lastX = event.x;
            } else if (!decided) {
                const dx = Math.abs(event.x - pressX), dy = Math.abs(event.y - pressY);
                if (dx >= Theme.dragThreshold && dx >= dy) {
                    decided = true;
                    lastX = event.x;
                    scrubbing = canScrub && row._ctl.scrubBegin();
                } else if (dy >= Theme.dragThreshold) {
                    decided = true;
                }
            }
        }
        onReleased: {
            if (scrubbing) {
                scrubbing = false;
                row._ctl.scrubEnd(true);
            } else if (!decided && containsMouse && row._ctl && typeof row._ctl.activate === "function") {
                row._ctl.activate();
            }
        }
        onCanceled: {
            if (scrubbing) {
                scrubbing = false;
                row._ctl.scrubEnd(false);
            }
        }

        Text {
            id: labelText
            objectName: "label"
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            text: row.label
            elide: Text.ElideRight
            color: row.control && !row.control.enabled ? Theme.textTertiary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Theme.textRenderType
        }

        // The full label, only when it was cut; or the description.
        Tip {
            text: row.description !== "" ? row.description : (labelText.truncated ? row.label : "")
            shown: labelArea.containsMouse
            pressed: labelArea.pressed
        }
    }

    Item {
        id: slot
        x: row.stacked ? Theme.gutter : Theme.gutter + row._labelWidth
        y: row.stacked ? 22 : 2
        width: Math.max(0, Math.min(row.inspector ? row.inspector.maximumFieldWidth : 280,
                                    row.width - x - Theme.panelPadding))
        height: row.height - y - 2
    }

    Binding {
        target: row.control
        property: "width"
        value: slot.width
        when: row._fill && row.control !== null
    }
    Binding {
        target: row.control
        property: "y"
        value: row.control ? Math.round((slot.height - row.control.height) / 2) : 0
        when: row.control !== null
    }

    Loader {
        id: menuLoader
        active: false
        sourceComponent: Menu {
            id: rowMenu
            objectName: "rowMenu"
            MenuItem {
                text: qsTr("Reset to Default")
                enabled: row.modified
                onTriggered: row._ctl.reset()
            }
            MenuSeparator { }
            MenuItem {
                text: qsTr("Copy Value")
                enabled: !!row._ctl && typeof row._ctl.copyText === "function"
                onTriggered: Clipboard.copy(row._ctl.copyText())
            }
            MenuItem {
                text: qsTr("Paste Value")
                enabled: !!row._ctl && typeof row._ctl.pasteText === "function"
                onTriggered: row._ctl.pasteText(Clipboard.paste())
            }
            MenuSeparator { visible: copyReference.visible || pasteLink.visible; height: visible ? implicitHeight : 0 }
            MenuItem {
                id: copyReference
                text: qsTr("Copy Reference")
                visible: !!row._param && !!row._param.reference
                height: visible ? implicitHeight : 0
                onTriggered: Clipboard.copy(String(row._param.reference))
            }
            MenuItem {
                id: pasteLink
                text: qsTr("Paste as Link")
                visible: row._canLink
                height: visible ? implicitHeight : 0
                onTriggered: {
                    const reference = Clipboard.paste().trim();
                    if (reference !== "")
                        row._ctl.setExpression(reference);
                }
            }
            MenuItem {
                text: qsTr("Edit Expression")
                visible: row._canLink && row._state === Param.Driven
                height: visible ? implicitHeight : 0
                onTriggered: row._ctl.activate()
            }
            MenuItem {
                text: qsTr("Remove Expression")
                visible: row._canLink && row._state === Param.Driven
                height: visible ? implicitHeight : 0
                onTriggered: row._ctl.setExpression("")
            }
            MenuSeparator { visible: row.menu.length > 0; height: visible ? implicitHeight : 0 }
            Instantiator {
                model: row.menu
                delegate: MenuItem {
                    required property var modelData
                    text: modelData.text ?? ""
                    enabled: modelData.enabled !== false
                    onTriggered: if (typeof modelData.triggered === "function") modelData.triggered()
                }
                onObjectAdded: (index, object) => rowMenu.addItem(object as MenuItem)
                onObjectRemoved: (index, object) => rowMenu.removeItem(object as MenuItem)
            }
        }
    }
}
