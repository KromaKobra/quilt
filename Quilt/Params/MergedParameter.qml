import QtQuick
import Quilt.Controls

// Several parameters shown as one, for a multiple selection. It reports
// Param.Mixed when they differ, and an edit goes to all of them.
//
//     MergedParameter { sources: selection.map(shape => params.find(shape.id + ".width")) }
//
// It carries the label, type and hints of the first source, so a generated
// Inspector treats it like any other parameter.
QtObject {
    id: merged

    property var sources: []                // Parameters (or any objects with the same members)

    readonly property var _live: (sources || []).filter(p => !!p)
    readonly property var first: _live.length > 0 ? _live[0] : null
    readonly property bool mixed: {
        for (let i = 1; i < _live.length; ++i)
            if (String(_live[i].value) !== String(_live[0].value))
                return true;
        return false;
    }
    readonly property bool driven: _live.some(p => p.state === Param.Driven)

    readonly property var value: first ? first.value : undefined
    readonly property var defaultValue: first ? first.defaultValue : undefined
    readonly property int state: mixed ? Param.Mixed : first ? first.state : Param.Normal
    readonly property string expression: !mixed && first ? first.expression : ""
    readonly property string message: mixed ? qsTr("The %1 selected values differ").arg(_live.length) : first ? first.message : ""
    readonly property string reference: _live.length === 1 ? first.reference : ""
    readonly property bool readOnly: _live.some(p => p.readOnly === true)

    readonly property string name: first ? first.name : ""
    readonly property string label: first ? first.label : ""
    readonly property string type: first ? first.type : ""
    readonly property string group: first ? first.group : ""
    readonly property string description: first ? first.description : ""
    readonly property string control: first ? first.control : ""
    // The first source's hints (from, to, suffix, options, …), as an
    // Inspector reads them.
    readonly property var hints: first ? (first.hints ?? first) : ({})

    function setValue(v) { _live.forEach(p => p.setValue(v)); }
    function setExpression(text) { _live.forEach(p => p.setExpression(text)); }
    function reset() { _live.forEach(p => p.reset()); }
    // One transaction for the lot: only the first source reports it.
    function beginEdit() { if (first) first.beginEdit(); }
    function endEdit(committed) { if (first) first.endEdit(committed); }
}
