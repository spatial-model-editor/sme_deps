#!/bin/bash

set -e -x

DEPSDIR=${INSTALL_PREFIX}

DUNE_COPASI_VERSION="v1.0.0"

echo "DUNE_COPASI_VERSION: ${DUNE_COPASI_VERSION}"
echo "PATH: $PATH"
echo "MSYSTEM: $MSYSTEM"

which g++
which cmake
g++ --version
gcc --version
cmake --version

echo "Downloading static libs for OS_TARGET: $OS_TARGET"
# download static libs
for LIB in common
do
    wget "https://github.com/spatial-model-editor/sme_deps_${LIB}/releases/latest/download/sme_deps_${LIB}_${OS_TARGET}.tgz"
    tar xvf sme_deps_${LIB}_${OS_TARGET}.tgz
done
pwd
ls
# copy libs to desired location: workaround for tar -C / not working on windows
if [[ "$OS_TARGET" == *"win"* ]]; then
   mv smelibs /c/
   ls /c/smelibs
else
   $SUDOCMD mv opt/* /opt/
   ls /opt/smelibs
fi

# export vars for duneopts script to read
export DUNE_COPASI_USE_STATIC_DEPS=ON
export CMAKE_INSTALL_PREFIX=$DEPSDIR
export MAKE_FLAGS="-j2 VERBOSE=1"
if [[ $MSYSTEM ]]; then
  # on windows add flags to support large object files
  # https://stackoverflow.com/questions/16596876/object-file-has-too-many-sections
  export CMAKE_CXX_FLAGS='-Wa,-mbig-obj'
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

ls $DEPSDIR
mkdir artefacts
cd artefacts
tar -zcvf sme_deps_dune_${OS_TARGET}.tgz $DEPSDIR/*
