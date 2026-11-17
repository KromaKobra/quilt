import QtQuick
import "Paint.js" as Paint

// The background of anything you press or type into: a field, a button, a
// segment, a highlighted menu row. `role` says which; the states say how it
// looks right now:
//
//     background: Face { role: Face.Button; hovered: control.hovered; pressed: control.down }
//
// Quilt draws it as a flat rounded rectangle. A theme redraws it with
// `skins.field` (role Field), `skins.segment` (Segment), `skins.item` (Item)
// or `skins.button` (the rest); the painter reads the states below and the
// resolved `fill`, `ink` and `edge`, so an application's own colours still
// apply. Provisional: the roles and states may change in the next release.
Rectangle {
    id: face

    enum Role {
        Field,      // a value you type into or drag: number, text, dropdown, date, colour
        Button,     // a push button
        Primary,    // the one main action of a view
        Tool,       // a borderless button: an icon, a menu title, a window button
        Step,       // the − and + inside a number field
        Track,      // the groove a segmented button's segments sit in
        Segment,    // the selected part of a segmented button
        Item        // a row in a menu or list; a day in a calendar
    }

    // (Compared as numbers below: a binding that names an enum looks the
    // type up each time it runs, and there is one Face per field.)
    property int role: Face.Field
    property bool hovered: false
    property bool pressed: false
    property bool checked: false        // on, selected, current
    property bool focused: false        // has keyboard focus
    property bool invalid: false        // the value can't be used
    property bool focusRing: false      // ring the face while focused or invalid
    property bool flat: false           // no fill: a read-only field, a flat button
    property bool driven: false         // the value is computed elsewhere
    property bool danger: false         // a destructive button: a window's close
    property bool marked: false         // outlined: today in a calendar

    // A field that is also a slider: how far along its range the value is.
    // The control draws the level; a painter draws it instead.
    property bool leveled: false
    property real level: 0              // 0..1
    property bool levelActive: false    // being dragged

    // What Quilt draws; a painter draws with these too.
    readonly property color fill: {
        switch (role) {
        case 0:
            return flat ? "transparent" : hovered ? Theme.controlHover : Theme.control;
        case 2:
            return pressed ? Theme.mix(Theme.accent, Theme.accentInk, 0.18)
                           : hovered ? Theme.mix(Theme.accent, Theme.text, 0.12) : Theme.accent;
        case 1:
            return pressed || checked ? Theme.controlFill
                 : hovered ? Theme.controlHover : flat ? "transparent" : Theme.control;
        case 3:
            return danger && hovered ? Theme.danger
                 : pressed || checked ? Theme.controlFill : hovered ? Theme.controlHover : "transparent";
        case 4:
            return pressed || hovered ? Theme.controlFill : "transparent";
        case 5:
            return Theme.control;
        case 6:
            return !checked ? "transparent" : driven ? Theme.mix(Theme.controlFill, Theme.driven, 0.35) : Theme.controlFill;
        default:
            return checked ? Theme.accent : hovered ? Theme.controlFill : "transparent";
        }
    }
    readonly property color edge: role === 6 ? Theme.focus
                                : marked && !checked ? Theme.textTertiary : Theme.controlBorder

    readonly property Component painter: {
        const s = Theme.skins;
        switch (role) {
        case 0: return s.field;
        case 6: return s.segment;
        case 7: return s.item;
        default: return s.button;
        }
    }
    readonly property bool skinned: painter !== null

    // The colour of text and glyphs on the face. (A function, so the many
    // faces of Quilt's own look don't each pay for a binding.)
    function ink(): color {
        return !enabled ? Theme.textTertiary
             : role === 2 || (role === 7 && checked) ? Theme.accentInk
             : danger && hovered ? Theme.dangerInk
             : role === 6 || role === 7 ? Theme.fillInk : Theme.text;
    }

    // A brief flash in the accent: Quilt corrected what the user entered.
    function flash() { Paint.flash(face, () => face.radius); }

    implicitHeight: Theme.controlHeight
    radius: role === 6 || role === 4 ? Theme.innerRadius : Theme.controlRadius
    color: skinned ? "transparent" : fill
    border.width: {
        if (skinned)
            return 0;
        switch (role) {
        case 0:
            return flat ? 0 : Theme.controlBorderWidth;
        case 1:
        case 5:
            return Theme.controlBorderWidth;
        case 6:
            return focused ? 1 : 0;
        case 7:
            return marked && !checked ? 1 : 0;
        default:
            return 0;
        }
    }
    border.color: edge

    property Item _painted: null
    property Item _ring: null
    property Item _flash: null
    function _ringShown(): bool { return focusRing && (focused || invalid); }
    function _wantRing() {
        if (!_ring && _ringShown())
            Paint.ring(face, () => face._ringShown(), () => face.radius, 0);
    }
    onPainterChanged: Paint.apply(face, painter)
    onFocusedChanged: _wantRing()
    onInvalidChanged: _wantRing()
    Component.onCompleted: {
        if (painter)
            Paint.apply(face, painter);
        _wantRing();
    }
}
