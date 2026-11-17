pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// The property grid: a scrolling column of Sections and PropertyRows that
// keeps every label and value aligned.
//
//     Inspector {
//         Section {
//             title: "Transform"
//             PropertyRow { label: "Rotation"; NumberField { … } }
//         }
//     }
//
// Or let it build the rows from parameter objects (see docs/controls.md,
// "A generated inspector"):
//
//     Inspector { model: selection.parameters }
//
// The user can drag the boundary between labels and values. In a narrow
// panel the rows restack with the label on top.
Item {
    id: inspector

    default property alias content: column.data

    // Width of the label column. Follows the panel until the user drags it.
    property real labelWidth: _autoLabelWidth
    readonly property real _autoLabelWidth: Math.round(Math.min(200, Math.max(80, (width - Theme.gutter) * 0.38)))
    property real maximumFieldWidth: 280    // controls stop growing here
    property real stackBelow: 200           // narrower than this, labels go above their controls
    property string filter                  // show only rows whose label contains this
    property bool searchable: false         // a field above the rows that sets `filter`
    property string emptyText               // shown when there are no rows, e.g. "Nothing selected"
    property color background: Theme.surface    // what the inspector sits on, for the scroll fades

    // Parameter objects to build rows from: a JS array, a list of QObjects,
    // a ListModel or a C++ item model (docs/controls-guide.md has the
    // details). `delegates` adds your own controls for your own types:
    // { "curve": Component }.
    property var model: null
    property var delegates: ({})

    readonly property bool stacked: width < stackBelow
    readonly property bool isQuiltInspector: true
    readonly property alias contentY: flick.contentY
    readonly property alias contentHeight: flick.contentHeight
    readonly property int count: _params.length    // generated rows

    // Scrolls so that `item` (somewhere inside) can be seen.
    function reveal(item: Item) {
        const top = item.mapToItem(column, 0, 0).y;
        const max = Math.max(0, flick.contentHeight - flick.height);
        if (top < flick.contentY + 4)
            flick.contentY = Math.max(0, top - 4);
        else if (top + item.height > flick.contentY + flick.height - 4)
            flick.contentY = Math.min(max, top + item.height - flick.height + 4);
    }

    // ---- generated rows

    readonly property var _hintNames: ["from", "to", "minimum", "maximum", "step", "stepSize", "decimals", "integer",
        "suffix", "displayScale", "wrap", "logarithmic", "steppers", "units", "exclusive", "alpha", "swatches",
        "labels", "linkable", "mode", "seconds", "placeholderText", "minimumLines", "maximumLines", "live", "options"]

    // The parameter objects, whatever kind of model they came in.
    readonly property bool _itemModel: !!model && typeof model === "object" && typeof model.length !== "number"
    property var _adapted: []
    readonly property var _params: {
        if (_itemModel)
            return _adapted;
        const out = [];
        for (let i = 0; model && i < model.length; ++i)
            if (model[i])
                out.push(model[i]);
        return out;
    }

    // What decides the rows: each parameter's section and kind of control.
    // (A value is only looked at when a parameter doesn't say what it is.)
    readonly property var _shape: _params.map(p => [String(p.group ?? ""), _kind(p)])
    property var _groups: []                // [{ name, params }]: the parameter objects, by section
    property var _layout: []                // [{ name, rows: [kind] }]: what to build
    property string _signature: "[]"

    // Rows are only rebuilt when their structure changes. Selecting another
    // object of the same kind keeps the rows, and with them the scroll
    // position and open sections, and just points them at new parameters.
    on_ShapeChanged: {
        const groups = [];
        _params.forEach((p, i) => {
            const name = _shape[i][0];
            let g = groups.find(x => x.name === name);
            if (!g)
                groups.push(g = { name: name, params: [], rows: [] });
            g.params.push(p);
            g.rows.push(_shape[i][1]);
        });
        const layout = groups.map(g => ({ name: g.name, rows: g.rows }));
        const signature = JSON.stringify(layout);
        _groups = groups;
        if (signature !== _signature) {
            _signature = signature;
            _layout = layout;
        }
    }

    function _kind(p): string {
        const named = p.control || p.type;
        if (named)
            return String(named);
        const v = p.value;
        return typeof v === "boolean" ? "bool" : typeof v === "string" ? "string" : "number";
    }

    function _component(kind: string): Component {
        if (delegates && delegates[kind])
            return delegates[kind];
        switch (kind) {
        case "bool": return boolDelegate;
        case "switch": return switchDelegate;
        case "string": case "text": return textDelegate;
        case "textarea": case "multiline": return areaDelegate;
        case "enum": case "options": return comboDelegate;
        case "segmented": return segmentedDelegate;
        case "slider": return sliderDelegate;
        case "color": return colorDelegate;
        case "vector": return vectorDelegate;
        case "date": case "time": case "datetime": return dateDelegate;
        default: return numberDelegate;         // number, int, float, angle, …
        }
    }

    // The hints a parameter carries (from, to, suffix, options, …): its own
    // properties, or one `hints` object. Called from a binding, so a hint
    // that changes later is picked up.
    function _readHints(p): var {
        const out = {};
        if (!p)
            return out;
        const source = p.hints ?? p;
        for (const h of _hintNames) {
            const v = source[h];
            if (v !== undefined && v !== null)
                out[h] = v;
        }
        if (p.type === "int")
            out.integer = true;
        if ((p.type === "time" || p.type === "datetime") && out.mode === undefined)
            out.mode = p.type;
        return out;
    }

    // Copies the hints onto the row's control and hands it the parameter.
    function _applyHints(loader: Loader, p, hints) {
        if (!loader.item || !p)
            return;
        // A hint that went away can't be taken back off a control: load a fresh one.
        for (const h in loader.applied) {
            if (!(h in hints)) {
                loader.applied = ({});
                loader.active = false;
                loader.active = true;       // onLoaded brings us back here
                return;
            }
        }
        const item = loader.item;
        for (const h in hints) {
            const name = h === "options" ? "model" : h;
            if (name in item && item[name] !== hints[h])
                item[name] = hints[h];
        }
        loader.applied = hints;
        if ("param" in item && item.param !== p)
            item.param = p;
    }

    Component { id: numberDelegate; NumberField { } }
    Component { id: boolDelegate; CheckBox { } }
    Component { id: switchDelegate; Switch { } }
    Component { id: textDelegate; TextField { } }
    Component { id: areaDelegate; TextArea { } }
    Component { id: comboDelegate; ComboBox { } }
    Component { id: segmentedDelegate; SegmentedButton { } }
    Component { id: sliderDelegate; Slider { } }
    Component { id: colorDelegate; ColorField { } }
    Component { id: vectorDelegate; VectorField { } }
    Component { id: dateDelegate; DateField { } }

    // One row of an item model, as a parameter object. A row either carries
    // a whole parameter object in a `parameter` role, or is described by
    // roles named like the parameter's members: value, label, type, group, …
    component RowAdapter: QtObject {
        required property var model
        readonly property var parameter: model.parameter ?? null

        readonly property var value: model.value
        readonly property var defaultValue: model.defaultValue
        readonly property var state: model.state
        readonly property var expression: model.expression
        readonly property var message: model.message
        readonly property var reference: model.reference
        readonly property var readOnly: model.readOnly
        readonly property var label: model.label ?? model.name
        readonly property var type: model.type
        readonly property var group: model.group
        readonly property var description: model.description
        readonly property var control: model.control
        readonly property var hints: model
        // Typing "=…" is only offered when the model has somewhere to put it.
        readonly property var setExpression: model.expression !== undefined
                                             ? (text => { model.expression = text; }) : undefined

        function setValue(v) { model.value = v; }
    }

    Instantiator {
        id: adapters
        model: inspector._itemModel ? inspector.model : null
        delegate: RowAdapter { }
        function collect() {
            const out = [];
            for (let i = 0; i < count; ++i) {
                const row = objectAt(i) as RowAdapter;
                if (row)
                    out.push(row.parameter ?? row);
            }
            inspector._adapted = out;
        }
        onObjectAdded: collect()
        onObjectRemoved: Qt.callLater(collect)      // the row is still counted while it is being removed
    }

    component GeneratedRow: PropertyRow {
        id: generated
        required property int groupIndex
        required property int index
        required property string modelData      // the kind of control
        readonly property var parameter: {
            const g = inspector._groups[groupIndex];
            return g && g.params[index] ? g.params[index] : null;
        }
        readonly property var hints: inspector._readHints(parameter)

        label: parameter ? String(parameter.label ?? parameter.name ?? "") : ""
        description: parameter && parameter.description ? String(parameter.description) : ""
        onHintsChanged: inspector._applyHints(loader, parameter, hints)
        Loader {
            id: loader
            property var applied: ({})
            sourceComponent: inspector._component(generated.modelData)
            onLoaded: inspector._applyHints(loader, generated.parameter, generated.hints)
        }
    }

    TextField {
        id: search
        objectName: "filterField"
        x: Theme.panelPadding
        y: 8
        width: parent.width - 2 * Theme.panelPadding
        visible: inspector.searchable
        search: true
        live: true
        placeholderText: qsTr("Filter")
        text: inspector.filter
        onEdited: t => inspector.filter = t
        Keys.onEscapePressed: event => {
            if (text !== "")
                inspector.filter = "";
            else
                event.accepted = false;
        }
    }

    Flickable {
        id: flick
        anchors { fill: parent; topMargin: inspector.searchable ? search.y + search.height + 4 : 0 }
        contentWidth: width
        contentHeight: column.height + 8
        interactive: false                  // the wheel scrolls; a drag belongs to the controls
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        T.ScrollBar.vertical: ScrollBar { }

        property real target: 0

        // Rows that go away (a filter, a collapsed section) never leave the view scrolled past its end.
        onContentHeightChanged: {
            const max = Math.max(0, contentHeight - height);
            if (contentY > max) {
                glide.stop();
                contentY = max;
            }
        }

        NumberAnimation {
            id: glide
            target: flick
            property: "contentY"
            duration: Theme.duration
            easing.type: Theme.easing
        }

        // A focused control that wants the wheel takes it before we see it.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const max = Math.max(0, flick.contentHeight - flick.height);
                const precise = event.pixelDelta.y !== 0;
                const delta = precise ? event.pixelDelta.y : event.angleDelta.y / 120 * 2 * Theme.rowHeight;
                const from = glide.running ? flick.target : flick.contentY;
                flick.target = Math.min(max, Math.max(0, from - delta));
                if (precise || Theme.duration === 0) {
                    glide.stop();
                    flick.contentY = flick.target;
                } else {
                    glide.to = flick.target;
                    glide.restart();
                }
            }
        }

        Column {
            id: column
            width: flick.width
            topPadding: 4

            // Parameters without a group come first, outside any section.
            Repeater {
                model: inspector._layout
                delegate: Loader {
                    id: group
                    required property var modelData
                    required property int index
                    width: column.width
                    sourceComponent: modelData.name === "" ? looseRows : sectionRows

                    Component {
                        id: looseRows
                        Column {
                            width: group.width
                            Repeater {
                                model: group.modelData.rows
                                delegate: GeneratedRow { groupIndex: group.index }
                            }
                        }
                    }
                    Component {
                        id: sectionRows
                        Section {
                            title: group.modelData.name
                            Repeater {
                                model: group.modelData.rows
                                delegate: GeneratedRow { groupIndex: group.index }
                            }
                        }
                    }
                }
            }
        }
    }

    // Keyboard focus that moves off-screen is followed.
    Connections {
        target: inspector.Window.window
        function onActiveFocusItemChanged() {
            const item = inspector.Window.window.activeFocusItem;
            for (let p = item; p; p = p.parent) {
                if (p === column) {
                    inspector.reveal(item);
                    return;
                }
            }
        }
    }

    // More above / more below: the overlay scroll bar hides at rest, so a
    // soft fade says the content continues.
    Rectangle {
        anchors { left: flick.left; right: flick.right; top: flick.top }
        height: 12
        visible: flick.contentY > 1
        gradient: Gradient {
            GradientStop { position: 0; color: inspector.background }
            GradientStop { position: 1; color: Theme.alpha(inspector.background, 0) }
        }
    }
    Rectangle {
        anchors { left: flick.left; right: flick.right; bottom: flick.bottom }
        height: 16
        visible: flick.contentY < flick.contentHeight - flick.height - 1
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(inspector.background, 0) }
            GradientStop { position: 1; color: inspector.background }
        }
    }

    // The boundary between labels and values: invisible until hovered.
    // Drag it to resize the label column; double-click to size it automatically again.
    MouseArea {
        id: divider
        x: Theme.gutter + inspector.labelWidth - 7
        y: flick.y
        width: 8
        height: Math.min(flick.height, column.height)
        visible: !inspector.stacked && column.height > column.topPadding + 1
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SplitHCursor
        property real grab: 0
        onPressed: event => grab = event.x
        onPositionChanged: event => {
            if (!pressed)
                return;
            const x = mapToItem(inspector, event.x - grab, 0).x + 7 - Theme.gutter;
            inspector.labelWidth = Math.round(Math.min(inspector.width - Theme.gutter - 72, Math.max(48, x)));
        }
        onDoubleClicked: inspector.labelWidth = Qt.binding(() => inspector._autoLabelWidth)
        Rule {
            x: 3
            width: 1
            height: parent.height
            ink: divider.pressed ? Theme.accent : Theme.border
            visible: divider.containsMouse || divider.pressed
        }
    }

    Text {
        objectName: "emptyText"
        anchors.centerIn: flick
        width: parent.width - 2 * Theme.panelPadding
        readonly property bool nothing: column.height <= column.topPadding + 1
        visible: nothing && text !== ""
        text: inspector.filter !== "" ? qsTr("Nothing matches “%1”").arg(inspector.filter) : inspector.emptyText
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: Theme.textTertiary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        renderType: Theme.textRenderType
    }
}
