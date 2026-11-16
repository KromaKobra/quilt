import QtQml

// Makes a property read its binding again.
//
// Qt's checkable controls flip `checked` themselves when clicked. A binding
// such as `checked: document.visible` stays installed, but is not evaluated
// again until `document.visible` changes, so a click the application refused
// leaves the control showing the wrong state. Quilt's own controls call
// refresh() after every click; you can do the same for a stock control:
//
//     CheckBox {
//         id: box
//         checked: document.visible
//         onToggled: { document.setVisible(checked); rebind.refresh(); }
//         Rebind { id: rebind; target: box; property: "checked" }
//     }
//
// A property that has no binding keeps its value.
Binding {
    id: rebind

    when: false
    restoreMode: Binding.RestoreBinding

    function refresh() {
        if (!target)
            return;
        value = target[property];
        when = true;                    // sets the binding aside…
        when = false;                   // …and puts it back, which evaluates it
    }
}
