DEPSDIR=${Env:INSTALL_PREFIX}

echo "SME_DEPS_COMMON_VERSION: ${Env:SME_DEPS_COMMON_VERSION}"
echo "DUNE_COPASI_VERSION: ${Env:DUNE_COPASI_VERSION}"

# download common static libs
$client = New-Object System.Net.WebClient
$client.DownloadFile("https://github.com/spatial-model-editor/sme_deps_common/releases/download/${Env:SME_DEPS_COMMON_VERSION}/sme_deps_common_${Env:OS_TARGET}.tgz", "C:\deps.tgz")
7z e C:\deps.tgz
7z x tmp.tar
rm tmp.tar
mv smelibs C:\
ls C:\smelibs

function install_dune($module, $repo, $branch) {

git clone -b $branch --depth 1 https://gitlab.dune-project.org/$repo/dune-$module.git
cd dune-$module
mkdir build
cd build
cmake -G "Ninja" .. `
    -DCMAKE_BUILD_TYPE=Release `
    -DBUILD_SHARED_LIBS=OFF `
    -DCMAKE_INSTALL_PREFIX="${Env:INSTALL_PREFIX}" `
    -DCMAKE_PREFIX_PATH="${Env:INSTALL_PREFIX}"
cmake --build . --parallel
cmake --install
cd ../../

}

install_dune "common" "core" "releases/2.7"
install_dune "logging" "staging" "releases/2.7"
install_dune "uggrid" "staging" "releases/2.7"
install_dune "geometry" "core" "releases/2.7"
install_dune "grid" "core" "releases/2.7"
install_dune "localfunctions" "core" "releases/2.7"
install_dune "istl" "core" "releases/2.7"
install_dune "typetree" "copasi" "support/dune-copasi-v1.1.0"
install_dune "functions" "staging" "releases/2.7"
install_dune "pdelab" "copasi" "support/dune-copasi-v1.1.0"
install_dune "copasi" "copasi" "${Env:DUNE_COPASI_VERSION}"

mkdir artefacts
cd artefacts
7z a tmp.tar $Env:INSTALL_PREFIX
7z a sme_deps_llvm_$Env:OS_TARGET.tgz tmp.tar
rm tmp.tar
