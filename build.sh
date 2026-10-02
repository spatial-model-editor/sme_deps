#!/bin/bash

set -e -x

echo "SME_DEPS_COMMON_VERSION: ${SME_DEPS_COMMON_VERSION}"
echo "DUNE_COPASI_VERSION: ${DUNE_COPASI_VERSION}"
echo "PATH: $PATH"

# export vars for duneopts script to read
export OS_TARGET="${OS}"
export CMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}
export CMAKE_C_COMPILER_LAUNCHER=ccache
export CMAKE_CXX_COMPILER_LAUNCHER=ccache

# disable libstdc++ pstl TBB backend: on Ubuntu 22.04 (libstdc++ 12) it still uses the old TBB API that was removed in oneTBB
export CMAKE_CXX_FLAGS='"-fvisibility=hidden -D_GLIBCXX_USE_TBB_PAR_BACKEND=0"'
export BUILD_SHARED_LIBS=OFF
export CMAKE_DISABLE_FIND_PACKAGE_MPI=ON
export DUNE_ENABLE_PYTHONBINDINGS=OFF
export DUNE_PDELAB_ENABLE_TRACING=OFF
export DUNE_COPASI_DISABLE_FETCH_PACKAGE_ExprTk=ON
export CMAKE_DISABLE_FIND_PACKAGE_parafields=ON
export DUNE_COPASI_DISABLE_FETCH_PACKAGE_parafields=ON
# build dune-copasi with 2d and 3d support
export DUNE_COPASI_GRID_DIMENSIONS='"2;3"'
if [[ $BUILD_TAG == "_tsan" ]]; then
    export CMAKE_CXX_FLAGS='"-fvisibility=hidden -D_GLIBCXX_USE_TBB_PAR_BACKEND=0 -fsanitize=thread -fno-omit-frame-pointer"'
fi

# clone dune-copasi (with retries for flaky gitlab)
for attempt in 1 2 3 4; do
    if git clone -b ${DUNE_COPASI_VERSION} --depth 1 https://gitlab.dune-project.org/copasi/dune-copasi.git; then
        break
    fi
    if [ $attempt -eq 4 ]; then
        echo "git clone failed after 4 attempts"
        exit 1
    fi
    rm -rf dune-copasi
    echo "Attempt $attempt failed, retrying in $((attempt * 5)) seconds..."
    sleep $((attempt * 5))
done
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

ls ${INSTALL_PREFIX}
mkdir artefacts
cd artefacts
tar -zcf sme_deps_${OS}${BUILD_TAG}.tgz ${INSTALL_PREFIX}/*
