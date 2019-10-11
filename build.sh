DUNE_VERSION="master"

# make sure we get the right mingw64 version of g++ on appveyor
PATH=/mingw64/bin:$PATH
echo "PATH=$PATH"
echo "MSYSTEM: $MSYSTEM"

which g++
which python
which cmake
g++ --version
gcc --version
cmake --version

WDIR=$(pwd)

# in future for release mode consider -DDUNE_MAX_LOGLEVEL=off
echo 'CMAKE_FLAGS=" -G '"'"'Unix Makefiles'"'"' -DDUNE_MAX_LOGLEVEL=trace "' > opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_CXX_STANDARD=17 "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_INSTALL_PREFIX='"$WDIR"'/dune "' >> opts.txt
echo 'CMAKE_FLAGS+=" -DGMPXX_INCLUDE_DIR:PATH='"$WDIR"'/gmp/include -DGMPXX_LIB:FILEPATH='"$WDIR"'/gmp/lib/libgmpxx.a -DGMP_LIB:FILEPATH='"$WDIR"'/gmp/lib/libgmp.a"' >> opts.txt
echo 'CMAKE_FLAGS+=" -Dfmt_ROOT='"$WDIR"'/fmt"' >> opts.txt
echo 'CMAKE_FLAGS+=" -Dmuparser_ROOT='"$WDIR"'/muparser -DTIFF_ROOT='"$WDIR"'/libtiff"' >> opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_DISABLE_FIND_PACKAGE_QuadMath=TRUE -DBUILD_TESTING=OFF -DDUNE_USE_ONLY_STATIC_LIBS=ON -DCMAKE_BUILD_TYPE=Release -DF77=true"' >> opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_CXX_FLAGS='"'"'-fvisibility=hidden -fpic -static-libstdc++'"'"' "' >> opts.txt
# on windows add flags to support large object files & statically link libgcc.
# https://stackoverflow.com/questions/16596876/object-file-has-too-many-sections
if [[ $MSYSTEM ]]; then
	echo 'CMAKE_FLAGS+=" -DCMAKE_CXX_FLAGS='"'"'-Wa,-mbig-obj -fvisibility=hidden -fpic -static -static-libgcc -static-libstdc++'"'"' "' >> opts.txt
fi
echo 'MAKE_FLAGS="-j2 VERBOSE=1"' >> opts.txt

export DUNE_OPTIONS_FILE="opts.txt"
export DUNECONTROL=./dune-common/bin/dunecontrol

# download & setup dune-copasi build
git clone -b master --depth 1 --recursive https://gitlab.dune-project.org/copasi/dune-copasi.git
bash dune-copasi/.ci/setup.sh

# remove testtools
rm -rf dune-testtools
# patch make install for uggrid
cd dune-uggrid
git apply ../uggrid-patch.diff
cd ..
cd dune-copasi
git apply ../copasi-patch.diff
cd ..
cd dune-pdelab
git apply ../pdelab-patch.diff
cd ..
cd dune-common
git apply ../common-patch.diff
cd ..

# build & test
bash dune-copasi/.ci/build.sh
bash dune-copasi/.ci/unit_tests.sh
bash dune-copasi/.ci/system_tests.sh

# install dune-copasi
$DUNECONTROL make install

# manually add config.h & FC.h headers for now...
cp dune-copasi/build-cmake/config.h $WDIR/dune/include/.
cp dune-copasi/build-cmake/FC.h $WDIR/dune/include/.

# remove docs & binaries
rm -rf dune/bin
rm -rf dune/share

ls dune
ls dune/*
du -sh dune

# print linker flags
cat dune-copasi/build-cmake/src/CMakeFiles/dune_copasi.dir/flags.make
if [[ $MSYSTEM ]]; then
	cat dune-copasi/build-cmake/src/CMakeFiles/dune_copasi.dir/linklibs.rsp
	ldd dune-copasi/build-cmake/src/dune_copasi.exe
fi
