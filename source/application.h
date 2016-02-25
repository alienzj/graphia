#ifndef APPLICATION_H
#define APPLICATION_H

#include "loading/fileidentifier.h"

#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QRect>
#include <QColor>

#include <tuple>
#include <memory>

#include <QCoreApplication>

class GraphModel;
class GraphFileParser;

class Application : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QStringList nameFilters READ nameFilters NOTIFY nameFiltersChanged)
    Q_PROPERTY(QColor textColor READ textColor NOTIFY textColorChanged)

public:
    explicit Application(QObject *parent = nullptr);

    bool parserAndModelForFile(const QUrl& url, const QString& fileTypeName,
                               std::unique_ptr<GraphFileParser>& graphFileParser,
                               std::shared_ptr<GraphModel>& graphModel) const;

signals:
    void nameFiltersChanged();
    void textColorChanged();

public slots:
    bool canOpen(const QString& fileTypeName) const;
    bool canOpenAnyOf(const QStringList& fileTypeNames) const;
    QStringList fileTypesOf(const QUrl& url) const;

    static QString name() { return QCoreApplication::applicationName(); }
    static const char* uri() { return _uri; }
    static int majorVersion() { return _majorVersion; }
    static int minorVersion() { return _minorVersion; }

    QString baseFileNameForUrl(const QUrl& url) const { return url.fileName(); }
    QUrl urlForFileName(const QString& fileName) const { return QUrl::fromLocalFile(fileName); }

    bool debugEnabled() const
    {
#ifdef _DEBUG
        return true;
#else
        return false;
#endif
    }

private:
    static const char* _uri;
    static const int _majorVersion = 1;
    static const int _minorVersion = 0;

    FileIdentifier _fileIdentifier;

    QColor textColor() const;
    QStringList nameFilters() const { return _fileIdentifier.nameFilters(); }
};

#endif // APPLICATION_H
