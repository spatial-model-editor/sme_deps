#!/bin/bash
DEPSDIR=${1:-"C:\libs"}

DUNE_COPASI_VERSION="20-add-special-membranes-for-species-that-only-pass-through-to-it-but-not-diffuse"

# make sure we get the right mingw64 version of g++ on appveyor
PATH=/mingw64/bin:$PATH
echo "DUNE_COPASI_VERSION: ${DUNE_COPASI_VERSION}"
echo "PATH: $PATH"
echo "MSYSTEM: $MSYSTEM"

which g++
which python
which cmake
g++ --version
gcc --version
cmake --version

DEPSDIR=${1:-"C:/libs"}
WDIR=$(pwd)

echo 'CMAKE_FLAGS=" -G '"'"'Unix Makefiles'"'"'"' > opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_CXX_STANDARD=17 "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_BUILD_TYPE=Release "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_INSTALL_PREFIX='"$WDIR"'/dune "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DGMPXX_INCLUDE_DIR:PATH='"$DEPSDIR"'/include "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DGMPXX_LIB:FILEPATH='"$DEPSDIR"'/lib/libgmpxx.a "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DGMP_LIB:FILEPATH='"$DEPSDIR"'/lib/libgmp.a "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_PREFIX_PATH='"$DEPSDIR"' "' >> opts.txt
echo 'CMAKE_FLAGS+=" -Dfmt_ROOT='"$DEPSDIR"' "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DDUNE_PYTHON_VIRTUALENV_SETUP=0 -DDUNE_PYTHON_ALLOW_GET_PIP=0 "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_DISABLE_FIND_PACKAGE_QuadMath=TRUE -DBUILD_TESTING=OFF "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DDUNE_USE_ONLY_STATIC_LIBS=ON -DF77=true"' >> opts.txt
if [[ $MSYSTEM ]]; then
	# on windows add flags to support large object files & statically link libgcc.
	# https://stackoverflow.com/questions/16596876/object-file-has-too-many-sections
	echo 'CMAKE_FLAGS+=" -DCMAKE_CXX_FLAGS='"'"'-Wa,-mbig-obj -fvisibility=hidden -fpic -static -static-libgcc -static-libstdc++'"'"' "' >> opts.txt
else
    echo 'CMAKE_FLAGS+=" -DCMAKE_CXX_FLAGS='"'"'-fvisibility=hidden -fpic -static-libstdc++'"'"' "' >> opts.txt
fi
echo 'MAKE_FLAGS="-j2 VERBOSE=1"' >> opts.txt

export DUNE_OPTIONS_FILE="opts.txt"
export DUNECONTROL=./dune-common/bin/dunecontrol

# download & setup dune-copasi build
git clone -b ${DUNE_COPASI_VERSION} --depth 1 --recursive https://gitlab.dune-project.org/copasi/dune-copasi.git
bash dune-copasi/.ci/setup.sh

# remove testtools
rm -rf dune-testtools

# build & test
bash dune-copasi/.ci/build.sh
bash dune-copasi/.ci/unit_tests.sh
bash dune-copasi/.ci/system_tests.sh

# install dune-copasi
$DUNECONTROL make install

# remove docs & binaries
rm -rf dune/bin
rm -rf dune/share

ls dune
ls dune/*
du -sh dune

# print linker flags
cat dune-copasi/build-cmake/src/CMakeFiles/dune_copasi_md.dir/flags.make
if [[ $MSYSTEM ]]; then
	cat dune-copasi/build-cmake/src/CMakeFiles/dune_copasi_md.dir/linklibs.rsp
	ldd dune-copasi/build-cmake/src/dune_copasi_md.exe
fi
