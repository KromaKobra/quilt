import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// A yes/no property of the thing being edited.
//
//     CheckBox { text: "Visible"; checked: shape.visible; onEdited: v => shape.visible = v }
//
// A mixed selection (paramState: Param.Mixed) shows a dash; clicking it
// turns the property on for everything.
T.CheckBox {
    id: control

    // Parameter state. See docs/controls.md.
    property var param: null                    // a parameter object; replaces the properties below
    property var defaultValue                   // enables the modified marker and reset()
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool readOnly: false
    property bool acceptsExpressions: false
    readonly property bool modified: edit.modified

    signal editStarted()
    signal edited(bool value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }  // "" removes it
    // What clicking the row label does.
    function activate() { control.forceActiveFocus(Qt.MouseFocusReason); control._toggle(); }
    function copyText(): string { return control.checked ? "true" : "false"; }
    function pasteText(text: string) {
        const t = text.trim().toLowerCase();
        if (!edit.readOnly && (t === "true" || t === "false" || t === "1" || t === "0"))
            edit.instant(t === "true" || t === "1");
    }

    function _toggle() {
        if (!edit.readOnly && !edit.driven)
            edit.instant(edit.mixed ? true : !control.checked);
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.controlHeight
    spacing: 8
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    // The template must not flip the box by itself: every change goes
    // through `edit`, so the box always shows the application's value.
    nextCheckState: function() { return control.checkState; }
    onClicked: control._toggle()

    indicator: Rectangle {
        readonly property bool on: control.checked || edit.mixed
        x: control.leftPadding
        y: Math.round((control.height - height) / 2)
        width: 14
        height: 14
        radius: Theme.innerRadius
        color: on ? (edit.driven ? Theme.driven : Theme.accent)
                  : control.down ? Theme.controlHover : "transparent"
        border.width: on ? 0 : 1.5
        border.pixelAligned: false
        border.color: control.hovered ? Theme.textSecondary : Theme.textTertiary
        opacity: edit.readOnly ? 0.6 : 1

        Icon {
            anchors.centerIn: parent
            visible: parent.on
            name: edit.mixed ? "dash" : "check"
            size: 10
            strokeWidth: 1.8
            color: Theme.accentInk
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2.5
            radius: parent.radius + 2.5
            color: "transparent"
            border.width: Theme.focusWidth
            border.pixelAligned: false
            border.color: Theme.accent
            visible: control.visualFocus
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        visible: control.text !== ""
        text: control.text
        font: control.font
        renderType: Theme.textRenderType
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    Tip { text: edit.message; shown: control.hovered }

    ValueEdit { id: edit; owner: control; name: "checked"; fallback: false }
}
