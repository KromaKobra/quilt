#pragma once

#include <QColor>
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

#include <algorithm>
#include <cmath>

// The application's data: an ordinary QObject. Quilt's controls bind to its
// properties as they would to any others, and nothing here knows about Quilt.
//
// The setters have the last word. A size is a whole number of pixels between
// 8 and 400, whatever was typed or dragged, and a locked shape refuses every
// change. The controls show what ended up here, not what was asked for.
class Shape : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(qreal width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(qreal height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(qreal rotation READ rotation WRITE setRotation NOTIFY rotationChanged)
    Q_PROPERTY(qreal opacity READ opacity WRITE setOpacity NOTIFY opacityChanged)
    Q_PROPERTY(qreal corners READ corners WRITE setCorners NOTIFY cornersChanged)
    Q_PROPERTY(QColor fill READ fill WRITE setFill NOTIFY fillChanged)
    Q_PROPERTY(bool locked READ locked WRITE setLocked NOTIFY lockedChanged)

public:
    using QObject::QObject;

    QString name() const { return m_name; }
    qreal width() const { return m_width; }
    qreal height() const { return m_height; }
    qreal rotation() const { return m_rotation; }
    qreal opacity() const { return m_opacity; }
    qreal corners() const { return m_corners; }
    QColor fill() const { return m_fill; }
    bool locked() const { return m_locked; }

    void setName(const QString &name)
    {
        if (set(m_name, name.trimmed().isEmpty() ? QStringLiteral("Untitled") : name.trimmed()))
            emit nameChanged();
    }
    void setWidth(qreal width)
    {
        if (set(m_width, std::clamp(std::round(width), 8.0, 400.0)))
            emit widthChanged();
    }
    void setHeight(qreal height)
    {
        if (set(m_height, std::clamp(std::round(height), 8.0, 400.0)))
            emit heightChanged();
    }
    void setRotation(qreal degrees)
    {
        if (set(m_rotation, degrees))
            emit rotationChanged();
    }
    void setOpacity(qreal opacity)
    {
        if (set(m_opacity, std::clamp(opacity, 0.0, 1.0)))
            emit opacityChanged();
    }
    void setCorners(qreal radius)
    {
        if (set(m_corners, std::max(0.0, radius)))
            emit cornersChanged();
    }
    void setFill(const QColor &fill)
    {
        if (set(m_fill, fill))
            emit fillChanged();
    }
    void setLocked(bool locked)
    {
        if (m_locked == locked)
            return;
        m_locked = locked;
        emit lockedChanged();
    }

signals:
    void nameChanged();
    void widthChanged();
    void heightChanged();
    void rotationChanged();
    void opacityChanged();
    void cornersChanged();
    void fillChanged();
    void lockedChanged();

private:
    template <typename T>
    bool set(T &member, const T &value)
    {
        if (m_locked || member == value)
            return false;
        member = value;
        return true;
    }

    QString m_name = QStringLiteral("Rectangle");
    qreal m_width = 220;
    qreal m_height = 140;
    qreal m_rotation = 0;
    qreal m_opacity = 1;
    qreal m_corners = 16;
    QColor m_fill = QColor(0x4c, 0x8d, 0xff);
    bool m_locked = false;
};
