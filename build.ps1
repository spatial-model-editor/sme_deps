echo "SME_DEPS_COMMON_VERSION: ${Env:SME_DEPS_COMMON_VERSION}"
echo "DUNE_COPASI_VERSION: ${Env:DUNE_COPASI_VERSION}"
echo "DUNE_VERSION: ${Env:DUNE_VERSION}"
echo "DUNE_SUPPORT_VERSION: ${Env:DUNE_SUPPORT_VERSION}"

# download common static libs

# $client = New-Object System.Net.WebClient
# $client.DownloadFile("https://github.com/spatial-model-editor/sme_deps_common/releases/download/${Env:SME_DEPS_COMMON_VERSION}/sme_deps_common_${Env:OS_TARGET}.tgz", "C:\deps.tgz")
# 7z e C:\deps.tgz
# 7z x tmp.tar
# rm tmp.tar
# mv smelibs C:\
# ls C:\smelibs

# remove any fortran compilers
rm C:\*\*\bin\gfortran.exe

# function to download, compile & install a dune module

function install_dune($module, $repo, $branch) {
    echo "${repo}/${module}/${branch}..."
    git clone -b ${branch} --depth 1 https://gitlab.dune-project.org/${repo}/dune-${module}.git
    cd dune-$module
    mkdir build
    cd build
    cmake -G "Ninja" .. `
        -DCMAKE_BUILD_TYPE=Release `
        -DBUILD_SHARED_LIBS=OFF `
        -DCMAKE_INSTALL_PREFIX="${Env:INSTALL_PREFIX}" `
        -DCMAKE_PREFIX_PATH="${Env:INSTALL_PREFIX}" `
        -DDUNE_USE_FALLBACK_FILESYSTEM="${Env:DUNE_USE_FALLBACK_FILESYSTEM}" `
        -DDISABLE_CXX_VERSION_CHECK=ON `
        -DCMAKE_CXX_FLAGS="/permissive-" `
        -DCXX_MAX_SUPPORTED_STANDARD=17 `
        -DCMAKE_CXX_STANDARD=17
    cmake --build . --parallel
    cmake --install .
    cd ..\..
}

# install each dune module in the required order

install_dune "common" "liam.keegan" "msvc"
install_dune "logging" "staging" "${Env:DUNE_VERSION}"
install_dune "uggrid" "staging" "${Env:DUNE_VERSION}"
install_dune "geometry" "core" "${Env:DUNE_VERSION}"
install_dune "grid" "core" "${Env:DUNE_VERSION}"
install_dune "localfunctions" "core" "${Env:DUNE_VERSION}"
install_dune "istl" "core" "${Env:DUNE_VERSION}"
install_dune "typetree" "copasi" "${Env:DUNE_SUPPORT_VERSION}"
install_dune "functions" "staging" "${Env:DUNE_VERSION}"
install_dune "pdelab" "copasi" "${Env:DUNE_SUPPORT_VERSION}"
install_dune "copasi" "copasi" "${Env:DUNE_COPASI_VERSION}"

mkdir artefacts
cd artefacts
7z a tmp.tar $Env:INSTALL_PREFIX
7z a sme_deps_llvm_$Env:OS_TARGET.tgz tmp.tar
rm tmp.tar
