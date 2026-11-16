import QtQuick
import Quilt.Controls

// One value of your application, described so that an inspector can show
// it and so that it can follow other values through an expression.
//
//     Parameter { name: "cube.width"; label: "Width"; value: 100; defaultValue: 100; suffix: " px" }
//     Parameter { name: "cube.height"; label: "Height"; value: 50; expression: "width / 2" }
//
// Read `value`. It is the entered value, or the expression's result while
// an expression is set. Every Quilt control accepts one as `param:`, and
// Inspector { model: … } builds rows from a list of them.
QtObject {
    id: parameter

    // ---- what it is

    property string name                    // unique in its ParameterSet; what expressions call it
    property string label: name.split(".").pop()
    property string type                    // number, int, bool, string, enum, color, vector, date, …
    property string group                   // the inspector section it belongs to
    property string description             // tooltip on its row
    property string control                 // ask for a specific control: slider, segmented, switch, …

    // ---- its value

    property var value: 0
    property var defaultValue
    property string expression              // "" when the value is not driven
    property bool readOnly: false

    readonly property int state: _error !== "" ? Param.Invalid
                               : expression !== "" ? Param.Driven : Param.Normal
    readonly property string message: _error !== "" ? _error
                                    : expression !== "" ? "= " + expression : ""
    readonly property string reference: name    // what "Copy Reference" copies

    // ---- hints for its control; leave unset to take the control's defaults

    property var from                       // numbers: NumberField, Slider, VectorField
    property var to
    property var minimum
    property var maximum
    property var step
    property var stepSize
    property var decimals
    property var integer
    property var suffix
    property var displayScale
    property var wrap
    property var logarithmic
    property var steppers
    property var units
    property var live
    property var options                    // an enum: the ComboBox / SegmentedButton model
    property var exclusive
    property var alpha                      // a colour
    property var swatches
    property var labels                     // a vector
    property var linkable
    property var mode                       // a date: "date", "time" or "datetime"
    property var seconds
    property var placeholderText            // text
    property var minimumLines
    property var maximumLines

    // The ParameterSet this belongs to; set by the set.
    property var parameterSet: null

    signal edited(var value)                // the user changed it (through a control)

    // ---- what controls call

    // Sets a plain value. This replaces an expression, if there was one.
    function setValue(v) {
        if (readOnly)
            return;
        _settingValue = true;
        if (expression !== "")
            expression = "";
        _error = "";
        value = _coerce(v);
        _settingValue = false;
        if (parameterSet)
            parameterSet._valueChanged(parameter);
        edited(value);
    }

    // Makes the value follow an expression; "" goes back to a plain value.
    function setExpression(text) {
        if (readOnly)
            return;
        expression = String(text).trim();
    }

    function reset() {
        if (readOnly)
            return;
        _settingValue = true;
        expression = "";
        _error = "";
        if (defaultValue !== undefined)
            value = defaultValue;
        _settingValue = false;
        if (parameterSet)
            parameterSet._valueChanged(parameter);
        edited(value);
    }

    function beginEdit() {
        if (parameterSet)
            parameterSet.editStarted(parameter);
    }

    function endEdit(committed) {
        if (parameterSet)
            parameterSet.editFinished(parameter, committed !== false);
    }

    // ---- internals

    property string _error
    property bool _settingValue: false
    property bool _evaluating: false

    // A number from an expression, as this parameter's kind of value.
    function _coerce(v) {
        if (type === "bool" || typeof value === "boolean")
            return typeof v === "number" ? v !== 0 : !!v;
        if (type === "int" || integer === true)
            return typeof v === "number" ? Math.round(v) : v;
        return v;
    }

    onExpressionChanged: {
        if (parameterSet)
            parameterSet._expressionChanged(parameter);
    }
    // The application may also write `value` directly (an animation, a tool).
    onValueChanged: {
        if (parameterSet && !_settingValue && !_evaluating)
            parameterSet._valueChanged(parameter);
    }
}
