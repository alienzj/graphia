TEMPLATE = lib
CONFIG += staticlib warn_off

TARGET = thirdparty

include(../common.pri)

include(qtsingleapplication/qtsingleapplication.pri)
include(breakpad/breakpad.pri)
include(SortFilterProxyModel/SortFilterProxyModel.pri)
include(qcustomplot/qcustomplot.pri)
include(qt-qml-models/QtQmlModels.pri)
include(cryptopp/cryptopp.pri)
include(zlib/zlib.pri)
