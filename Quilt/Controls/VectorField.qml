pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// Two to four numbers on one row: a position, a size, a scale.
//
//     VectorField { value: shape.position; onEdited: v => shape.position = v }
//     VectorField { value: shape.scale; linkable: true; linked: true; … }    // keeps proportions
//
// `value` may be an array, a vector2d/3d/4d, a point, a size or a rect, and
// edits come back as the same kind. Each component is a NumberField, so it
// drags, types and steps like one. Typing or pasting "1, 2, 3" into any
// component fills them all.
T.Control {
    id: control

    property var value: [0, 0, 0]
    property var labels                     // default: X Y Z W, or W H for a size
    property bool linkable: false           // show the chain toggle
    property bool linked: false             // editing one component scales the others in proportion

    // Passed on to every component; see NumberField.
    property bool integer: false
    property real from: Number.NEGATIVE_INFINITY
    property real to: Number.POSITIVE_INFINITY
    property real minimum: Number.NEGATIVE_INFINITY
    property real maximum: Number.POSITIVE_INFINITY
    property real step: integer ? 1 : 0.1
    property int decimals: integer ? 0 : 3
    property real displayScale: 1
    property string suffix
    property bool live: true

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property var componentStates            // optional: a Param state for each component
    property string expression
    property string message
    property bool readOnly: false
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool fillsRow: true
    readonly property int count: _parts.length

    signal editStarted()
    signal edited(var value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }
    function activate() {
        const first = fields.itemAt(0) as NumberField;
        if (first)
            first.beginEdit();
    }
    function copyText(): string { return edit.mixed ? "" : _parts.map(n => parseFloat(Number(n).toPrecision(12))).join(", "); }
    function pasteText(text: string) {
        const numbers = Expression.list(text);
        if (numbers)
            _fill(0, numbers);
        else if (isFinite(Number(text)) && text.trim() !== "")
            _fill(0, _parts.map(() => Number(text)));
    }

    readonly property var _parts: _split(edit.shown)
    readonly property var _labels: labels !== undefined && labels !== null ? labels
                                   : _kind(edit.shown) === "size" ? ["W", "H"]
                                   : _kind(edit.shown) === "rect" ? ["X", "Y", "W", "H"] : ["X", "Y", "Z", "W"]
    readonly property bool _stacked: count > 0 && (availableWidth - (linkable ? 24 : 0)) / count < 52
    property var _linkStart: []

    function _kind(v): string {
        if (v === undefined || v === null)
            return "array";
        if (typeof v === "number")
            return "number";
        if (typeof v.length === "number")       // (a vector has a length() method, not a length)
            return "array";
        if (v.width !== undefined)
            return v.x !== undefined ? "rect" : "size";
        if (v.w !== undefined)
            return "vector4d";
        if (v.z !== undefined)
            return "vector3d";
        return String(v).indexOf("QPoint") === 0 ? "point" : "vector2d";
    }

    function _split(v): var {
        switch (_kind(v)) {
        case "number": return [v];
        case "rect": return [v.x, v.y, v.width, v.height];
        case "size": return [v.width, v.height];
        case "vector4d": return [v.x, v.y, v.z, v.w];
        case "vector3d": return [v.x, v.y, v.z];
        case "point": case "vector2d": return [v.x, v.y];
        default: {
            const out = [];
            for (let i = 0; v && i < v.length; ++i)
                out.push(Number(v[i]));
            return out;
        }
        }
    }

    // The numbers as the same kind of value the application gave us.
    function _join(n): var {
        switch (_kind(edit.current)) {
        case "number": return n[0];
        case "rect": return Qt.rect(n[0], n[1], n[2], n[3]);
        case "size": return Qt.size(n[0], n[1]);
        case "vector4d": return Qt.vector4d(n[0], n[1], n[2], n[3]);
        case "vector3d": return Qt.vector3d(n[0], n[1], n[2]);
        case "point": return Qt.point(n[0], n[1]);
        case "vector2d": return Qt.vector2d(n[0], n[1]);
        default: return n;
        }
    }

    function _changed(index: int, v: real) {
        const next = _parts.slice();
        const base = _linkStart[index];
        if (linked && _linkStart.length === next.length && base !== 0 && isFinite(base)) {
            for (let i = 0; i < next.length; ++i)
                next[i] = i === index ? v : parseFloat((_linkStart[i] * v / base).toPrecision(12));
        } else {
            next[index] = v;
        }
        edit.set(_join(next));
    }

    function _fill(index: int, numbers) {
        const next = _parts.slice();
        for (let i = 0; i < numbers.length && index + i < next.length; ++i)
            next[index + i] = numbers[i];
        edit.instant(_join(next));
    }

    implicitWidth: 180
    implicitHeight: _stacked ? count * Theme.controlHeight + (count - 1) * 4 : Theme.controlHeight
    opacity: enabled ? 1 : 0.4

    Accessible.role: Accessible.Grouping
    Accessible.description: [copyText(), edit.stateText].filter(t => t !== "").join(", ")

    contentItem: Item {
        Grid {
            id: grid
            width: parent.width - (control.linkable ? 24 : 0)
            columns: control._stacked ? 1 : Math.max(1, control.count)
            spacing: 4

            Repeater {
                id: fields
                model: control.count
                delegate: NumberField {
                    id: part
                    required property int index
                    width: control._stacked ? grid.width
                                            : (grid.width - (control.count - 1) * grid.spacing) / Math.max(1, control.count)
                    value: control._parts[index] ?? 0
                    lead: control._labels[index] ?? ""
                    integer: control.integer
                    from: control.from
                    to: control.to
                    minimum: control.minimum
                    maximum: control.maximum
                    step: control.step
                    decimals: control.decimals
                    displayScale: control.displayScale
                    suffix: control.suffix
                    live: control.live
                    readOnly: edit.readOnly
                    message: edit.message
                    paramState: control.componentStates && control.componentStates[index] !== undefined
                                ? control.componentStates[index] : edit.state
                    listHandler: numbers => control._fill(numbers.length >= control.count ? 0 : part.index, numbers)

                    onEditStarted: {
                        edit.begin();
                        control._linkStart = control._split(edit.startValue);
                    }
                    onEdited: v => control._changed(index, v)
                    onEditFinished: committed => edit.end(committed)
                }
            }
        }

        IconButton {
            anchors { right: parent.right; top: parent.top }
            width: 20
            visible: control.linkable
            iconName: control.linked ? "link" : "unlink"
            color: control.linked ? Theme.accent : Theme.textTertiary
            tip: control.linked ? qsTr("Proportions are kept") : qsTr("Keep proportions")
            onClicked: control.linked = !control.linked
        }
    }

    ValueEdit { id: edit; owner: control; fallback: [0, 0, 0]; live: control.live }
}
