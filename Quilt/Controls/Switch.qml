import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// Turns a feature or a whole section on and off. For an ordinary yes/no
// property use a CheckBox.
//
//     Switch { checked: fx.enabled; onEdited: v => fx.enabled = v }
T.Switch {
    id: control

    property var param: null
    property var defaultValue
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
    function activate() {
        control.forceActiveFocus(Qt.MouseFocusReason);
        if (!edit.readOnly && !edit.driven)
            edit.instant(edit.mixed ? true : !control.checked);
    }
    function copyText(): string { return control.checked ? "true" : "false"; }
    function pasteText(text: string) {
        const t = text.trim().toLowerCase();
        if (!edit.readOnly && (t === "true" || t === "false" || t === "1" || t === "0"))
            edit.instant(t === "true" || t === "1");
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.controlHeight
    spacing: 8
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4

    Accessible.description: edit.stateText

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    // The template has already moved the thumb (a click or a drag). Report
    // it, then show whatever the application made of it.
    onToggled: {
        if (edit.readOnly || edit.driven)
            edit.restore(!control.checked);
        else
            edit.instant(control.checked);
    }

    indicator: Rectangle {
        readonly property bool on: control.checked && !edit.mixed
        x: control.leftPadding
        y: Math.round((control.height - height) / 2)
        width: 26
        height: 14
        radius: 7
        color: on ? (edit.driven ? Theme.driven : Theme.accent)
                  : control.hovered ? Theme.mix(Theme.controlFill, Theme.text, 0.1) : Theme.controlFill
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Rectangle {
            readonly property real travel: parent.width - width - 4
            x: 2 + (edit.mixed ? 0.5 : control.visualPosition) * travel
            y: 2
            width: 10
            height: 10
            radius: 5
            color: parent.on ? Theme.accentInk : Theme.textSecondary
            Behavior on x { enabled: !control.down; NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
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

    Tip { text: edit.message; shown: control.hovered; pressed: control.down }

    ValueEdit { id: edit; owner: control; name: "checked"; fallback: false }
}
