pragma Singleton
import QtQuick
import "ColorUtil.js" as ColorUtil

// The colours picked most recently, shared by every colour picker.
QtObject {
    property var recent: []
    property int limit: 12

    function add(c: color) {
        const rest = recent.filter(x => !ColorUtil.near(x, c));
        recent = [c].concat(rest).slice(0, limit);
    }
}
