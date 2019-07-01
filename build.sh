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

WORKING_DIR=$(pwd)

mkdir dune
cd dune
echo 'CMAKE_FLAGS=" -G '"'"'Unix Makefiles'"'"' -DGMPXX_INCLUDE_DIR:PATH='"$WORKING_DIR"'/gmp/include -DGMPXX_LIB:FILEPATH='"$WORKING_DIR"'/gmp/lib/libgmpxx.a -DGMP_LIB:FILEPATH='"$WORKING_DIR"'/gmp/lib/libgmp.a -DCMAKE_DISABLE_FIND_PACKAGE_QuadMath=TRUE -DBUILD_TESTING=OFF -DDUNE_USE_ONLY_STATIC_LIBS=ON -DCMAKE_BUILD_TYPE=Release -Dmuparser_ROOT='"$WORKING_DIR"'/muparser -DTIFF_ROOT='"$WORKING_DIR"'/libtiff -DF77=true "' > opts.txt
echo 'CMAKE_FLAGS+=" -DCMAKE_CXX_FLAGS='"'"'-static-libstdc++'"'"' "' >> opts.txt
# on windows add flags to support large object files
# https://stackoverflow.com/questions/16596876/object-file-has-too-many-sections
if [[ $MSYSTEM ]]; then
	echo 'CMAKE_FLAGS+=" -DCMAKE_CXX_FLAGS='"'"'-Wa,-mbig-obj -static -static-libgcc -static-libstdc++'"'"' "' >> opts.txt
fi
echo 'MAKE_FLAGS="-j2 VERBOSE=1"' >> opts.txt

# download Dune dependencies
for repo in dune-common dune-typetree dune-pdelab dune-multidomaingrid
do
  git clone -b support/dune-copasi --depth 1 --recursive https://gitlab.dune-project.org/santiago.ospina/$repo.git
done
for repo in core/dune-geometry core/dune-istl core/dune-localfunctions staging/dune-functions staging/dune-uggrid staging/dune-logging
do
  git clone -b $DUNE_VERSION --depth 1 --recursive https://gitlab.dune-project.org/$repo.git
done

# temporarily use fork of dunegrid to fix gmshreader on windows:
# todo: when fixed on master, add core/dune-grid back to list above
git clone -b gmsh_reader_fix --depth 1 --recursive https://gitlab.dune-project.org/liam.keegan/dune-grid.git

# on windows, symlinks from git repos don't work
# msys git replaces symlinks with a text file containing the linked file location
# so here we identify all such files, and replace them with the linked file
# note msys defines MSYSTEM variable: use this to check if we are on msys/windows
if [[ $MSYSTEM ]]; then
	rootdir=$(pwd)
		for repo in $(ls -d dune-*/)
		do
			echo "repo: $repo"
			cd $rootdir/$repo
			for f in $(git ls-files -s | awk '/120000/{print $4}')
			do
				dname=$(dirname "$f")
				fname=$(basename "$f")
				relf=$(cat $f)
				src="$rootdir/$repo/$dname/$relf"
				dst="$rootdir/$repo/$dname/$fname"
				echo "  - copying $src --> $dst"
				cp $src $dst
			done
		done
	cd $rootdir
fi

# patch cmake macro to avoid build failure when fortran compiler not found, e.g. on osx
cd dune-common
wget https://gist.githubusercontent.com/lkeegan/059984b71f8aeb0bbc062e85ad7ee377/raw/e9c7af42c47fe765547e60833a72b5ff1e78123c/cmake-patch.txt
echo '' >> cmake-patch.txt
git apply cmake-patch.txt
cd ../

# patch dune-logging cmake to not define FMT_SHARED
cd dune-logging
git apply ../../dune-logging.patch
cd ../

# download dune-copasi
git clone -b 2-include-more-options-to-initializate-stetes --depth 1 --recursive https://gitlab.dune-project.org/copasi/dune-copasi.git

./dune-common/bin/dunecontrol --module=dune-copasi printdeps
./dune-common/bin/dunecontrol --opts=opts.txt --module=dune-copasi all

cat dune-copasi/build-cmake/src/CMakeFiles/dune_copasi.dir/flags.make

if [[ $MSYSTEM ]]; then
	cat dune-copasi/build-cmake/src/CMakeFiles/dune_copasi.dir/linklibs.rsp
	ldd dune-copasi/build-cmake/src/dune_copasi.exe
fi
