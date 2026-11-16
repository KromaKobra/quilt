import QtQml

// The states a value can be in, e.g. `paramState: Param.Driven`.
// See "Parameter states" in docs/controls.md.
QtObject {
    enum State {
        Normal,     // an ordinary, editable value
        Driven,     // computed by something else: an expression, a link, an animation
        Mixed,      // several objects are selected and they differ
        Invalid     // the last entry or expression failed
    }
}
