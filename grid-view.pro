TARGET = grid-view
TEMPLATE = app

CONFIG += c++17

# for now require this to get c++17 features used by DUNE to compile:
QMAKE_MACOSX_DEPLOYMENT_TARGET = 10.14

DEFINES += DUNE_LOGGING_VENDORED_FMT=1 ENABLE_GMP=1 ENABLE_UG=1 HAVE_CONFIG_H MUPARSER_STATIC UG_USE_NEW_DIMENSION_DEFINES

QMAKE_CXXFLAGS += -Wno-unused-parameter

SOURCES += \
    grid-view.cpp \

# external libs

LIBS += \
    $$PWD/gmp/lib/libgmp.a \
    $$PWD/gmp/lib/libgmpxx.a \
    $$PWD/muparser/lib/libmuparser.a \

INCLUDEPATH += \
    $$PWD/gmp/include \
    $$PWD/muparser/include \

# dune libs

INCLUDEPATH += \
    $$PWD/build/dune-copasi \
    $$PWD/build/dune-copasi/build-cmake \
    $$PWD/build/dune-uggrid/low \
    $$PWD/build/dune-uggrid/gm \
    $$PWD/build/dune-uggrid/dom \
    $$PWD/build/dune-uggrid/np \
    $$PWD/build/dune-uggrid/ui \
    $$PWD/build/dune-uggrid/np/algebra \
    $$PWD/build/dune-uggrid/np/udm \
    $$PWD/build/dune-multidomaingrid \
    $$PWD/build/dune-pdelab \
    $$PWD/build/dune-logging \
    $$PWD/build/dune-common \
    $$PWD/build/dune-uggrid \
    $$PWD/build/dune-geometry \
    $$PWD/build/dune-typetree \
    $$PWD/build/dune-istl \
    $$PWD/build/dune-grid \
    $$PWD/build/dune-localfunctions \
    $$PWD/build/dune-functions \
    $$PWD/build/dune-logging/build-cmake/dune/vendor/fmt \

LIBS += \
    $$PWD/build/dune-logging/build-cmake/lib/libdune-logging.a \
    $$PWD/build/dune-logging/build-cmake/lib/libdune-logging-fmt.a \
    $$PWD/build/dune-pdelab/build-cmake/lib/libdunepdelab.a \
    $$PWD/build/dune-grid/build-cmake/lib/libdunegrid.a \
    $$PWD/build/dune-geometry/build-cmake/lib/libdunegeometry.a \
    $$PWD/build/dune-uggrid/build-cmake/lib/libugS3.a \
    $$PWD/build/dune-uggrid/build-cmake/lib/libugS2.a \
    $$PWD/build/dune-uggrid/build-cmake/lib/libugL.a \
    $$PWD/build/dune-common/build-cmake/lib/libdunecommon.a \
    $$PWD/build/dune-copasi/build-cmake/dune/copasi/libdune_copasi_lib.a \
