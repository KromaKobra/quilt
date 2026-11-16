pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style
import "ColorUtil.js" as ColorUtil

// A colour: a swatch, its hex value, and its opacity.
//
//     ColorField { value: shape.fill; onEdited: c => shape.fill = c }
//
// Click the swatch for the picker. The hex field takes #fff, fff, rrggbbaa,
// rgb(…) and colour names. The opacity drags like any number.
T.Control {
    id: control

    property color value: "#000000"
    property bool alpha: true               // the colour has opacity
    property var swatches: []               // your palette, offered in the picker
    property bool live: true

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool readOnly: false
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool fillsRow: true
    readonly property bool pickerOpen: _picker !== null

    signal editStarted()
    signal edited(color value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }
    function activate() { openPicker(); }
    function copyText(): string { return edit.mixed ? "" : "#" + ColorUtil.toHex(_color, alpha); }
    function pasteText(text: string) {
        const c = _parse(text);
        if (c !== null && !_locked)
            edit.instant(c);
    }

    function openPicker() {
        if (_locked || _picker)
            return;
        _picker = pickerComponent.createObject(control);
        _picker.load(edit.mixed ? Qt.rgba(0.5, 0.5, 0.5, 1) : _color);
        _picker.open();
    }

    readonly property color _color: edit.shown
    readonly property bool _locked: edit.readOnly || edit.driven || !enabled
    property ColorPicker _picker: null

    // A colour from text, or null. Text that gives no opacity keeps the
    // current one.
    function _parse(text: string): var {
        const keep = edit.mixed ? 1 : _color.a;
        const c = ColorUtil.parse(text);
        if (c)
            return Qt.rgba(c[0], c[1], c[2], !alpha ? 1 : c[4] ? c[3] : keep);
        try {
            const named = Qt.color(text.trim().toLowerCase());
            return Qt.rgba(named.r, named.g, named.b, alpha ? keep : 1);
        } catch (e) {
            return null;
        }
    }

    implicitWidth: 140
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1 : 0.4

    onValueChanged: if (_picker) _picker.sync(value)

    background: FieldFrame {
        hovered: hover.hovered
        focused: hex.activeFocus || opacityField.focused
        invalid: edit.invalid
        flat: edit.readOnly
    }
    HoverHandler { id: hover }

    contentItem: Item {
        Item {
            id: swatch
            x: 3
            y: 3
            width: 18
            height: 18

            Image {
                anchors { fill: parent; margins: 1 }
                visible: control._color.a < 1 && !edit.mixed
                source: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAAAAADhZOFXAAAAFklEQVR42mPoAYI0IGDAwwARIA4eBgBBhB5BaFSA3gAAAABJRU5ErkJggg=="
                fillMode: Image.Tile
                smooth: false
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.innerRadius
                color: edit.mixed ? Theme.controlFill : control._color
                border.width: 1
                border.color: Theme.alpha(Theme.text, swatchHover.hovered && !control._locked ? 0.5 : 0.12)
                Icon {
                    anchors.centerIn: parent
                    visible: edit.mixed
                    name: "dash"
                    size: 10
                }
            }
            HoverHandler { id: swatchHover }
            TapHandler { onTapped: control.openPicker() }
        }

        TextField {
            id: hex
            x: 20
            width: parent.width - x - (opacityField.visible ? opacityField.width : 0)
            height: parent.height
            flat: true
            readOnly: control._locked
            paramState: edit.state
            text: ColorUtil.toHex(control._color, false)
            font.features: ({ "tnum": 1 })
            // What can't be read as a colour is dropped: the field goes back
            // to showing the colour it has.
            onEdited: t => {
                const c = control._parse(t);
                if (c !== null)
                    edit.instant(c);
            }
        }

        NumberField {
            id: opacityField
            anchors.right: parent.right
            width: 50
            height: parent.height
            visible: control.alpha && !edit.mixed
            flat: true
            integer: true
            from: 0
            to: 100
            suffix: "%"
            readOnly: control._locked
            value: control._color.a * 100
            onEditStarted: edit.begin()
            onEdited: n => edit.set(Qt.rgba(control._color.r, control._color.g, control._color.b, n / 100))
            onEditFinished: committed => edit.end(committed)
        }
    }

    Component {
        id: pickerComponent
        ColorPicker {
            alpha: control.alpha
            swatches: control.swatches
            onPicked: c => edit.set(c)
            onClosed: {
                const kept = !cancelled && edit.active;
                edit.end(!cancelled);
                if (kept)
                    ColorHistory.add(control.value);
                control._picker = null;
                destroy();
            }
        }
    }

    Tip { text: edit.message; shown: hover.hovered && !control.pickerOpen }

    ValueEdit { id: edit; owner: control; fallback: "#808080"; live: control.live }
}
