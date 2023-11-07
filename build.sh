#!/bin/bash

set -e -x

DEPSDIR=${INSTALL_PREFIX}

echo "SME_DEPS_COMMON_VERSION: ${SME_DEPS_COMMON_VERSION}"
echo "DUNE_COPASI_VERSION: ${DUNE_COPASI_VERSION}"
echo "PATH: $PATH"
echo "MSYSTEM: $MSYSTEM"

export CXX=/usr/local/opt/llvm/bin/clang++
export CC=/usr/local/opt/llvm/bin/clang
#export LDFLAGS="/usr/local/opt/llvm/lib/c++/libc++.a /usr/local/opt/llvm/lib/c++/libc++abi.a /usr/local/opt/llvm/lib/c++/libc++experimental.a -L/usr/local/opt/llvm/lib -L/usr/local/opt/llvm/lib/c++ -Wl,-rpath,/usr/local/opt/llvm/lib/c++"
export LDFLAGS="-llibc++ -llibc++abi -llibc++experimental -L/usr/local/opt/llvmstatic/lib -L/usr/local/opt/llvmstatic/lib/c++ -Wl,-rpath,/usr/local/opt/llvmstatic/lib/c++"
export CPPFLAGS="-I/usr/local/opt/llvm/include"

otool -L /usr/local/opt/llvm/lib/c++/libc++.1.dylib

#ls /usr/local/opt/llvm/lib/*

sudo cp -r /usr/local/opt/llvm/ /usr/local/opt/llvmstatic/
sudo rm -rf /usr/local/opt/llvmstatic/lib/*.dylib
sudo rm -rf /usr/local/opt/llvmstatic/lib/*/*.dylib

$CXX --version

echo "Downloading static libs for OS_TARGET: $OS_TARGET"
wget "https://github.com/spatial-model-editor/sme_deps_common/releases/download/${SME_DEPS_COMMON_VERSION}/sme_deps_common_${OS_TARGET}.tgz"
tar xf sme_deps_common_${OS_TARGET}.tgz
# copy libs to desired location: workaround for tar -C / not working on windows
if [[ "$OS_TARGET" == *"win"* ]]; then
    mv c/smelibs /c/
    # ls /c/smelibs
else
    $SUDOCMD mv opt/* /opt/
    # ls /opt/smelibs
fi

# temp hack to remove muparser
rm -rf $DEPSDIR/lib/libmuparser.a
rm -rf $DEPSDIR/lib/cmake/muparser
rm -rf $DEPSDIR/include/muParser*

# export vars for duneopts script to read
export DUNE_COPASI_USE_STATIC_DEPS=ON
export CMAKE_INSTALL_PREFIX=$DEPSDIR
export MAKE_OPTIONS="-j2 VERBOSE=1"
# -fexperimental-library for clang/libc++ to enable <execution>
export CMAKE_CXX_FLAGS="'-fvisibility=hidden -fexperimental-library'"
export BUILD_SHARED_LIBS=OFF
export CMAKE_DISABLE_FIND_PACKAGE_MPI=ON
export DUNE_ENABLE_PYTHONBINDINGS=OFF
export DUNE_PDELAB_ENABLE_TRACING=OFF
export DUNE_PDELAB_USE_BOOST_ATOMIC_REF=ON
export DUNE_COPASI_DISABLE_FETCH_PACKAGE_ExprTk=ON
export DUNE_COPASI_DISABLE_FETCH_PACKAGE_parafields=ON
export DUNE_COPASI_USE_PARAFIELDS=OFF
if [[ $MSYSTEM ]]; then
    # on windows add flags to support large object files
    # https://stackoverflow.com/questions/16596876/object-file-has-too-many-sections
    export CMAKE_CXX_FLAGS='-fvisibility=hidden -Wa,-mbig-obj'
fi

# clone dune-copasi
git clone -b ${DUNE_COPASI_VERSION} --depth 1 https://gitlab.dune-project.org/copasi/dune-copasi.git
cd dune-copasi

# check opts
bash dune-copasi.opts

# build & install dune (excluding dune-copasi)
bash .ci/setup_dune $PWD/dune-copasi.opts

# build & install dune-copasi
bash .ci/install $PWD/dune-copasi.opts

cd ..

# patch DUNE to skip deprecated FindPythonLibs/FindPythonInterp cmake that breaks subsequent FindPython cmake
sed -i.bak 's|find_package(Python|#find_package(Python|' ${INSTALL_PREFIX}/share/dune/cmake/modules/DunePythonCommonMacros.cmake
# also patch out any dune_python_find_package() calls as this can crash on windows
sed -i.bak 's|dune_python_find_package(|#dune_python_find_package(|' ${INSTALL_PREFIX}/share/dune/cmake/modules/DunePythonCommonMacros.cmake
cat ${INSTALL_PREFIX}/share/dune/cmake/modules/DunePythonCommonMacros.cmake

/opt/smelibs/bin/dune-copasi --help

otool -L /opt/smelibs/bin/dune-copasi

# ls $DEPSDIR
#mkdir artefacts
#cd artefacts
#tar -zcf sme_deps_${OS_TARGET}.tgz $DEPSDIR/*
