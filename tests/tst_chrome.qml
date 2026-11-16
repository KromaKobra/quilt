pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quilt.Controls

// The supporting pieces: buttons, menus, tooltips, the title bar, scroll
// and progress indicators, and the theme itself.
Item {
    id: root
    width: 480
    height: 360

    property bool grid: false
    property int clicks: 0
    property var log: []

    Component { id: button; Button { text: "Apply"; onClicked: root.clicks += 1 } }
    Component { id: iconButton; IconButton { iconName: "reset"; tip: "Reset view"; onClicked: root.clicks += 1 } }

    Component {
        id: menu
        Menu {
            property alias gridAction: gridAction
            property alias refusedAction: refusedAction
            Action { text: "Open…"; shortcut: "Ctrl+O"; onTriggered: root.log.push("open") }
            Action { text: "Disabled"; enabled: false; onTriggered: root.log.push("disabled") }
            MenuSeparator { }
            Action { id: gridAction; text: "Grid"; checkable: true; checked: root.grid; onTriggered: root.grid = !root.grid }
            Action { id: refusedAction; text: "Locked"; checkable: true; checked: root.grid }
            Menu {
                title: "More"
                Action { text: "Deeper"; onTriggered: root.log.push("deeper") }
            }
        }
    }

    Component {
        id: windowComponent
        ApplicationWindow {
            id: win
            width: 640
            height: 400
            title: "Document — App"
            property alias bar: bar
            property alias content: content
            menuBar: TitleBar {
                id: bar
                Menu {
                    title: "&File"
                    Action { text: "New"; onTriggered: root.log.push("new") }
                    Action { text: "Close"; onTriggered: root.log.push("close") }
                }
                Menu {
                    title: "&Edit"
                    Action { text: "Undo"; onTriggered: root.log.push("undo") }
                }
                trailing: Button { text: "Share"; flat: true; onClicked: root.log.push("share") }
            }
            Rectangle { id: content; anchors.fill: parent; color: Theme.surface }
        }
    }

    Component {
        id: scroller
        Flickable {
            width: 200
            height: 100
            contentHeight: 1000
            clip: true
            property alias bar: bar
            ScrollBar.vertical: ScrollBar { id: bar }
            Rectangle { width: 200; height: 1000; color: Theme.control }
        }
    }

    Component { id: progress; ProgressBar { width: 200 } }
    Component { id: busy; BusyIndicator { } }

    TestCase {
        name: "Chrome"
        when: windowShown

        function init() {
            root.grid = false;
            root.clicks = 0;
            root.log = [];
        }

        function make(component, properties) {
            const item = createTemporaryObject(component, root, properties || {});
            verify(item);
            return item;
        }

        function find(item, predicate) {
            if (predicate(item))
                return item;
            for (let i = 0; i < item.children.length; ++i) {
                const found = find(item.children[i], predicate);
                if (found)
                    return found;
            }
            return null;
        }

        // ---- buttons

        function test_button() {
            const b = make(button);
            compare(b.height, Theme.controlHeight);
            mouseClick(b);
            compare(root.clicks, 1);
            b.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            compare(root.clicks, 2);
            b.enabled = false;
            mouseClick(b);
            compare(root.clicks, 2);
        }

        function test_checkable_button_follows_its_binding() {
            const b = make(button, { checkable: true, checked: Qt.binding(() => root.grid) });
            mouseClick(b);                      // nobody changed root.grid: the click is refused
            tryCompare(b, "checked", false);
            root.grid = true;
            compare(b.checked, true);

            const free = make(button, { y: 40, checkable: true });
            mouseClick(free);
            wait(20);
            compare(free.checked, true);        // without a binding it keeps its own state
        }

        function test_icon_button_and_its_tooltip() {
            const b = make(iconButton);
            compare(b.width, Theme.controlHeight);
            mouseClick(b);
            compare(root.clicks, 1);

            const delay = Theme.toolTipDelay;
            Theme.toolTipDelay = 30;
            mouseMove(b, 5, 5);
            mouseMove(b, 6, 6);
            const shown = () => find(b, i => i.text === "Reset view" && i.visible) !== null
                             || find(root.Window.window.contentItem.parent, i => i.text === "Reset view" && i.visible) !== null;
            tryVerify(shown, 2000);
            mouseMove(root, 300, 300);          // leaving hides it
            tryVerify(() => !shown(), 2000);
            Theme.toolTipDelay = delay;
        }

        // ---- menus

        function test_menu_actions() {
            const m = make(menu);
            m.popup(root, 20, 20);
            tryVerify(() => m.opened);
            const open = m.itemAt(0);
            compare(open.text, "Open…");
            compare(open.shortcutText, "Ctrl+O");
            mouseClick(open);
            tryVerify(() => !m.visible);
            compare(root.log, ["open"]);

            m.popup(root, 20, 20);
            tryVerify(() => m.opened);
            mouseClick(m.itemAt(1));            // disabled: nothing happens, the menu stays
            compare(root.log, ["open"]);
            verify(m.visible);
            keyClick(Qt.Key_Escape);
            tryVerify(() => !m.visible);
        }

        function test_menu_keyboard() {
            const m = make(menu);
            m.popup(root, 20, 20);
            tryVerify(() => m.opened);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            tryVerify(() => !m.visible);
            compare(root.log, ["open"]);
        }

        function test_checkable_action_follows_the_application() {
            const m = make(menu);
            m.popup(root, 20, 20);
            tryVerify(() => m.opened);
            const item = m.itemAt(3);
            verify(item.checkable);
            verify(!item.checked);
            mouseClick(item);
            tryVerify(() => !m.visible);
            compare(root.grid, true);
            compare(m.gridAction.checked, true);
            root.grid = false;                  // changed from elsewhere: the menu still follows
            compare(m.gridAction.checked, false);
        }

        function test_checkable_action_that_is_refused_snaps_back() {
            const m = make(menu);
            m.popup(root, 20, 20);
            tryVerify(() => m.opened);
            mouseClick(m.itemAt(4));            // "Locked" has no handler: nothing changes root.grid
            tryVerify(() => !m.visible);
            tryCompare(m.refusedAction, "checked", false);
            root.grid = true;
            compare(m.refusedAction.checked, true);
        }

        function test_submenu() {
            const m = make(menu);
            m.popup(root, 20, 20);
            tryVerify(() => m.opened);
            const more = m.itemAt(5);
            verify(more.subMenu);
            mouseClick(more);
            tryVerify(() => more.subMenu.opened);
            mouseClick(more.subMenu.itemAt(0));
            tryVerify(() => !m.visible);
            compare(root.log, ["deeper"]);
        }

        function test_menu_is_as_wide_as_its_widest_row() {
            const m = make(menu);
            m.popup(root, 20, 20);
            tryVerify(() => m.opened);
            for (let i = 0; i < m.count; ++i) {
                const item = m.itemAt(i);
                verify(item.width >= item.implicitWidth - 0.5, "row " + i);
            }
            keyClick(Qt.Key_Escape);
            tryVerify(() => !m.visible);
        }

        // ---- the title bar

        function openWindow(properties) {
            const win = createTemporaryObject(windowComponent, root, properties || {});
            verify(win);
            win.show();
            verify(waitForRendering(win.contentItem));
            return win;
        }

        function barItem(win, text) {
            return find(win.bar, i => i.text === text && String(i).indexOf("MenuBarItem") === 0);
        }

        function test_title_bar_shows_the_title_and_opens_menus() {
            const win = openWindow();
            const title = find(win.bar, i => i.text === "Document — App");
            verify(title);
            verify(title.visible);
            compare(win.bar.height, Theme.titleBarHeight);
            compare(win.content.mapToItem(null, 0, 0).y, Theme.titleBarHeight);

            const file = barItem(win, "&File");
            verify(file);
            mouseClick(file);
            const fileMenu = file.menu;
            tryVerify(() => fileMenu.opened);
            mouseClick(fileMenu.itemAt(0));
            tryVerify(() => !fileMenu.visible);
            compare(root.log, ["new"]);
        }

        function test_title_bar_slots() {
            const win = openWindow();
            const share = find(win.bar, i => i.text === "Share");
            verify(share);
            mouseClick(share);
            compare(root.log, ["share"]);
        }

        function test_title_bar_is_a_plain_menu_bar_with_the_system_frame() {
            const win = openWindow();
            verify(!win.bar.frameless);
            verify(!win.bar.windowButtons);
            verify(!find(win.bar, i => i.objectName === "windowButtons").visible);
        }

        function test_frameless_window_buttons() {
            const win = openWindow({ frameless: true });
            verify(win.bar.frameless);
            const buttons = find(win.bar, i => i.objectName === "windowButtons");
            verify(buttons.visible);
            compare(buttons.x + buttons.width, win.bar.width);      // they reach the window's corner
            compare(buttons.height, win.bar.height);
            const maximize = buttons.children[1], close = buttons.children[2];

            mouseClick(maximize);
            tryCompare(win, "visibility", Window.Maximized);
            verify(win.bar.maximized);
            mouseClick(maximize);
            tryCompare(win, "visibility", Window.Windowed);

            mouseDoubleClickSequence(win.bar, win.bar.width / 2, 8);     // on the bar itself
            tryCompare(win, "visibility", Window.Maximized);
            win.bar.toggleMaximized();
            tryCompare(win, "visibility", Window.Windowed);

            mouseClick(close);
            tryCompare(win, "visible", false);
        }

        function test_frameless_window_has_resize_edges() {
            const win = openWindow({ frameless: true });
            const frame = find(win.contentItem.parent, i => i.objectName === "resizeFrame");
            verify(frame);
            verify(frame.visible);
            compare(frame.width, win.width);
            let grips = 0;
            for (let i = 0; i < frame.children.length; ++i)
                if (frame.children[i].edges !== undefined)
                    grips += 1;
            compare(grips, 8);                  // four edges and four corners
            win.showMaximized();
            tryVerify(() => !frame.visible);    // nothing to resize when maximized
        }

        function test_application_window_carries_the_theme() {
            const win = openWindow();
            compare(win.color, Theme.canvas);
            compare(win.palette.highlight, Theme.accent);
            compare(win.palette.text, Theme.text);
        }

        // ---- scroll bar, progress, busy

        function test_scroll_bar_is_an_overlay_that_hides_at_rest() {
            const f = make(scroller);
            const bar = f.bar;
            compare(f.contentItem.width, 200);  // it takes no room from the content
            verify(bar.size < 1);
            verify(bar.contentItem.opacity < 0.01 || !bar.active);
            f.contentY = 300;
            verify(bar.position > 0);
            verify(bar.height * bar.size >= 23.5);      // the thumb is never tiny
            mouseMove(f, 196, 50);
            tryVerify(() => bar.contentItem.opacity > 0.99, 2000);
            mousePress(bar, 5, 40);
            mouseMove(bar, 5, 60, -1, Qt.LeftButton);
            mouseMove(bar, 5, 80, -1, Qt.LeftButton);
            mouseRelease(bar, 5, 80);
            verify(f.contentY > 300);
        }

        function test_progress_bar() {
            const p = make(progress, { value: 0.5 });
            compare(p.height, 4);
            fuzzyCompare(p.position, 0.5, 1e-9);
            p.indeterminate = true;
            verify(p.indeterminate);
        }

        function test_busy_indicator_waits_then_stays() {
            const b = make(busy, { running: false, delay: 100 });
            verify(!b.showing);
            b.running = true;
            wait(30);
            verify(!b.showing);                 // a short wait shows nothing
            b.running = false;
            wait(150);
            verify(!b.showing);

            b.running = true;
            tryVerify(() => b.showing, 1000);
            b.running = false;
            verify(b.showing);                  // it never just flickers
            tryVerify(() => !b.showing, 1000);
        }

        // ---- theme

        function test_theme_switches_and_can_be_overridden() {
            const dark = Theme.surface;
            Theme.dark = false;
            verify(Theme.surface !== dark);
            verify(Theme.text.hslLightness < 0.3);
            Theme.dark = true;
            compare(Theme.surface, dark);

            const b = make(button, { primary: true });
            const accent = Theme.accent;
            Theme.accent = "#ff8a3d";
            compare(b.background.color, Qt.color("#ff8a3d"));
            Theme.accent = accent;
        }

        function test_theme_tokens_meet_their_contrast_targets() {
            function luminance(c) {
                const f = x => x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
                return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
            }
            function contrast(a, b) {
                const la = luminance(a), lb = luminance(b);
                return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
            }
            for (const dark of [true, false]) {
                Theme.dark = dark;
                const tag = dark ? "dark " : "light ";
                for (const ground of [Theme.surface, Theme.control]) {
                    verify(contrast(Theme.text, ground) >= 7, tag + "text");
                    verify(contrast(Theme.textSecondary, ground) >= 4.5, tag + "textSecondary");
                    verify(contrast(Theme.textTertiary, ground) >= 3, tag + "textTertiary");
                    verify(contrast(Theme.accent, ground) >= 3, tag + "accent");
                    verify(contrast(Theme.driven, ground) >= 3, tag + "driven");
                    verify(contrast(Theme.error, ground) >= 3, tag + "error");
                }
                verify(contrast(Theme.accentInk, Theme.accent) >= 4.5, tag + "accentInk");
            }
            Theme.dark = true;
        }

        function test_step_factor() {
            compare(Theme.stepFactor(Qt.NoModifier), 1);
            compare(Theme.stepFactor(Qt.ShiftModifier), 10);
            compare(Theme.stepFactor(Qt.ControlModifier), 0.1);
        }
    }
}
