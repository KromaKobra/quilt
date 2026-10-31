#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtQml/qqmlextensionplugin.h>

// Quilt is built as a static QML module; this registers it with the engine.
Q_IMPORT_QML_PLUGIN(QuiltPlugin)

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // DockArea.autoSaveKey stores layouts with QtCore Settings, which files
    // them under the organization and application names.
    app.setOrganizationName("QuiltExample");
    app.setApplicationName("Quilt C++ host");

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("CppHost", "Main");

    return app.exec();
}
