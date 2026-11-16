#include <QGuiApplication>
#include <QQmlApplicationEngine>

// Quilt is linked in as compiled QML modules (see CMakeLists.txt). Linking
// them registers them with the QML engine, so there is nothing to do here
// beyond loading the application's own QML.
int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // DockArea.autoSaveKey and Section.key store their state with QtCore
    // Settings, which files it under the organization and application names.
    app.setOrganizationName("QuiltExample");
    app.setApplicationName("Quilt C++ host");

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("CppHost", "Main");

    return app.exec();
}
