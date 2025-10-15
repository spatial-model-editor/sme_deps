#!/bin/bash

set -e -x

echo "SME_DEPS_COMMON_VERSION: ${SME_DEPS_COMMON_VERSION}"
echo "DUNE_COPASI_VERSION: ${DUNE_COPASI_VERSION}"
echo "PATH: $PATH"
echo "MSYSTEM: $MSYSTEM"

# temporary workaround for cmake 4.0 complaining about symengine min cmake version being too low:
export CMAKE_POLICY_VERSION_MINIMUM=3.5

# export vars for duneopts script to read
export OS_TARGET="${OS}"
export CMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}"
export CMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}
export CMAKE_CXX_COMPILER_LAUNCHER=ccache

# disable gcc 10 pstl TBB backend as it uses the old TBB API
export CMAKE_CXX_FLAGS='"-fvisibility=hidden -D_GLIBCXX_USE_TBB_PAR_BACKEND=0 -DNDEBUG"'
export BUILD_SHARED_LIBS=OFF
export CMAKE_DISABLE_FIND_PACKAGE_MPI=ON
export DUNE_ENABLE_PYTHONBINDINGS=OFF
export DUNE_PDELAB_ENABLE_TRACING=OFF
export DUNE_COPASI_DISABLE_FETCH_PACKAGE_ExprTk=ON
export CMAKE_DISABLE_FIND_PACKAGE_parafields=ON
export DUNE_COPASI_DISABLE_FETCH_PACKAGE_parafields=ON
# build dune-copasi with 2d and 3d support
export DUNE_COPASI_GRID_DIMENSIONS='"2;3"'
if [[ $MSYSTEM ]]; then
    # on windows add flags to support large object files
    # https://stackoverflow.com/questions/16596876/object-file-has-too-many-sections
    export CMAKE_CXX_FLAGS='"-fvisibility=hidden -Wa,-mbig-obj -D_GLIBCXX_USE_TBB_PAR_BACKEND=0 -DNDEBUG"'
fi
if [[ $BUILD_TAG == "_tsan" ]]; then
    export CMAKE_CXX_FLAGS='"-fvisibility=hidden -D_GLIBCXX_USE_TBB_PAR_BACKEND=0 -DNDEBUG -fsanitize=thread -fno-omit-frame-pointer"'
fi

# clone dune-copasi
git clone -b ${DUNE_COPASI_VERSION} --depth 1 https://gitlab.dune-project.org/copasi/dune-copasi.git
cd dune-copasi
# get test data files
git lfs install
git lfs pull

# check opts
bash dune-copasi.opts

# build & install dune (excluding dune-copasi)
bash .ci/setup_dune $PWD/dune-copasi.opts

# build & install dune-copasi
bash .ci/install $PWD/dune-copasi.opts

# build & run dune-copasi tests
if [[ $BUILD_TAG == "_tsan" ]]; then
    echo "Skipping tests for TSAN build"
else
    bash .ci/test $PWD/dune-copasi.opts
fi

ccache --show-stats

cd ..

# patch DUNE to skip deprecated FindPythonLibs/FindPythonInterp cmake that breaks subsequent FindPython cmake
sed -i.bak 's|find_package(Python|#find_package(Python|' ${INSTALL_PREFIX}/share/dune/cmake/modules/DunePythonCommonMacros.cmake
# also patch out any dune_python_find_package() calls as this can crash on windows
sed -i.bak 's|dune_python_find_package(|#dune_python_find_package(|' ${INSTALL_PREFIX}/share/dune/cmake/modules/DunePythonCommonMacros.cmake
cat ${INSTALL_PREFIX}/share/dune/cmake/modules/DunePythonCommonMacros.cmake

ls ${INSTALL_PREFIX}
mkdir artefacts
cd artefacts
tar -zcf sme_deps_${OS}${BUILD_TAG}.tgz ${INSTALL_PREFIX}/*
