// quiltshot <app.qml> <script.txt>
//
// Loads a QML file whose root is a Window, then runs the script line by
// line and exits. Coordinates are in the current window's logical pixels.
//
//   wait <ms>                       let animations and timers run
//   window <n>                      act on window n (0: the main one; then pop-outs, in order)
//   size <w> <h>                    resize the current window
//   move <x> <y>                    move the pointer (hover)
//   click <x> <y> [right] [ctrl] [shift] [alt]
//   dclick <x> <y>                  double-click
//   press <x> <y> [right] [mods…] / release <x> <y> [right] [mods…]
//   drag <x1> <y1> <x2> <y2> [hold] [mods…]   press, move in steps, release (unless hold)
//   wheel <x> <y> <angleDelta>      one wheel event (120 is one notch up)
//   key <name> [mods…]              Tab Backtab Return Escape Up Down Left Right Space Menu F2 Home End Backspace
//   type <text>                     type characters
//   eval <expression>               evaluate JavaScript in the root object's context, print the result
//   shot <file.png>                 save the current window, popups included
//   windows                         list the open windows
//   # …                             a comment
//
// The QML import path is "." plus QUILT_IMPORT (colon-separated). With
// QT_SCALE_FACTOR=2 the screenshots are at twice the size.

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlExpression>
#include <QQuickWindow>
#include <QFile>
#include <QTest>
#include <QTimer>

static QQuickWindow *mainWindow = nullptr;
static QObject *rootObject = nullptr;
static QQmlApplicationEngine *engine = nullptr;

static QQuickWindow *windowAt(int index)
{
    QList<QQuickWindow *> windows;
    for (QWindow *w : QGuiApplication::topLevelWindows())
        if (auto *q = qobject_cast<QQuickWindow *>(w); q && q->isVisible() && q != mainWindow)
            windows << q;
    windows.prepend(mainWindow);
    return index < windows.size() ? windows[index] : nullptr;
}

static Qt::KeyboardModifiers modifiers(const QStringList &args)
{
    Qt::KeyboardModifiers m;
    if (args.contains("shift")) m |= Qt::ShiftModifier;
    if (args.contains("ctrl")) m |= Qt::ControlModifier;
    if (args.contains("alt")) m |= Qt::AltModifier;
    return m;
}

static bool run(const QStringList &lines)
{
    bool ok = true;
    QQuickWindow *win = mainWindow;
    for (QString line : lines) {
        line = line.trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;
        const QString cmd = line.section(' ', 0, 0);
        const QString rest = line.section(' ', 1);
        const QStringList a = rest.split(' ', Qt::SkipEmptyParts);
        const QPoint p(a.value(0).toInt(), a.value(1).toInt());
        const Qt::MouseButton button = a.contains("right") ? Qt::RightButton : Qt::LeftButton;

        if (cmd == "wait") {
            QTest::qWait(rest.toInt());
        } else if (cmd == "window") {
            win = windowAt(rest.toInt());
            if (!win) {
                qWarning("quiltshot: no window %d", rest.toInt());
                win = mainWindow;
                ok = false;
            }
        } else if (cmd == "size") {
            win->resize(a.value(0).toInt(), a.value(1).toInt());
            QTest::qWait(150);
        } else if (cmd == "move") {
            QTest::mouseMove(win, p);
        } else if (cmd == "press") {
            QTest::mousePress(win, button, modifiers(a), p);
        } else if (cmd == "release") {
            QTest::mouseRelease(win, button, modifiers(a), p);
        } else if (cmd == "click") {
            QTest::mouseMove(win, p);
            QTest::qWait(30);
            QTest::mouseClick(win, button, modifiers(a), p);
        } else if (cmd == "dclick") {
            QTest::mouseClick(win, Qt::LeftButton, modifiers(a), p);
            QTest::mouseDClick(win, Qt::LeftButton, modifiers(a), p);
        } else if (cmd == "drag") {
            const QPoint from(a.value(0).toInt(), a.value(1).toInt()), to(a.value(2).toInt(), a.value(3).toInt());
            QTest::mouseMove(win, from);
            QTest::qWait(20);
            QTest::mousePress(win, Qt::LeftButton, modifiers(a), from);
            for (int i = 1; i <= 8; ++i) {
                QTest::mouseMove(win, from + (to - from) * i / 8);
                QTest::qWait(10);
            }
            if (!a.contains("hold"))
                QTest::mouseRelease(win, Qt::LeftButton, modifiers(a), to);
        } else if (cmd == "wheel") {
            QWheelEvent event(p, win->mapToGlobal(p), QPoint(), QPoint(0, a.value(2).toInt()), Qt::NoButton,
                              Qt::NoModifier, Qt::NoScrollPhase, false);
            QCoreApplication::sendEvent(win, &event);
        } else if (cmd == "key") {
            static const QHash<QString, Qt::Key> keys{
                {"Tab", Qt::Key_Tab}, {"Backtab", Qt::Key_Backtab}, {"Return", Qt::Key_Return},
                {"Escape", Qt::Key_Escape}, {"Up", Qt::Key_Up}, {"Down", Qt::Key_Down}, {"Left", Qt::Key_Left},
                {"Right", Qt::Key_Right}, {"Space", Qt::Key_Space}, {"Menu", Qt::Key_Menu}, {"F2", Qt::Key_F2},
                {"Home", Qt::Key_Home}, {"End", Qt::Key_End}, {"Backspace", Qt::Key_Backspace}};
            if (!keys.contains(a.value(0))) {
                qWarning().noquote() << "quiltshot: unknown key" << a.value(0);
                ok = false;
            }
            QTest::keyClick(win, keys.value(a.value(0), Qt::Key_unknown), modifiers(a));
        } else if (cmd == "type") {
            for (QChar c : rest)
                QTest::keyClick(win, c.toLatin1());
        } else if (cmd == "eval") {
            QQmlExpression expression(engine->contextForObject(rootObject), rootObject, rest);
            const QVariant v = expression.evaluate();
            if (expression.hasError()) {
                qWarning().noquote() << "quiltshot: eval error:" << expression.error().toString();
                ok = false;
            } else {
                qInfo().noquote() << "eval:" << rest << "=>" << v.toString();
            }
        } else if (cmd == "shot") {
            QTest::qWait(60);
            if (!win->grabWindow().save(rest)) {
                qWarning().noquote() << "quiltshot: could not save" << rest;
                ok = false;
            }
        } else if (cmd == "windows") {
            for (int i = 0; windowAt(i); ++i)
                qInfo().noquote() << i << windowAt(i)->title() << windowAt(i)->geometry();
        } else {
            qWarning().noquote() << "quiltshot: unknown command:" << line;
            ok = false;
        }
        QCoreApplication::processEvents();
    }
    return ok;
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("QuiltShot");
    app.setApplicationName("quiltshot");
    if (app.arguments().size() < 3) {
        qWarning("usage: quiltshot <app.qml> <script.txt>");
        return 2;
    }

    QQmlApplicationEngine qml;
    engine = &qml;
    qml.addImportPath(".");
    for (const QString &path : qEnvironmentVariable("QUILT_IMPORT").split(':', Qt::SkipEmptyParts))
        qml.addImportPath(path);
    qml.load(QUrl::fromLocalFile(app.arguments().at(1)));
    if (qml.rootObjects().isEmpty())
        return 1;
    rootObject = qml.rootObjects().first();
    mainWindow = qobject_cast<QQuickWindow *>(rootObject);
    if (!mainWindow) {
        qWarning("quiltshot: the root object must be a Window");
        return 2;
    }

    QFile file(app.arguments().at(2));
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning().noquote() << "quiltshot: can't read" << file.fileName();
        return 2;
    }
    const QStringList lines = QString::fromUtf8(file.readAll()).split('\n');
    QTimer::singleShot(400, [&] { QCoreApplication::exit(run(lines) ? 0 : 1); });
    return app.exec();
}
