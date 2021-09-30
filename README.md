# sme_deps [![Release Builds](https://github.com/spatial-model-editor/sme_deps/actions/workflows/release.yml/badge.svg)](https://github.com/spatial-model-editor/sme_deps/actions/workflows/release.yml)

Static compilation of [spatial-model-editor](https://github.com/spatial-model-editor/spatial-model-editor) build dependencies.
These libraries are used to produce the binary releases, see [spatial-model-editor/ci](https://github.com/spatial-model-editor/spatial-model-editor/blob/master/ci/README.md) for more information.

This contains all of the libraries from [sme_deps_common](https://github.com/spatial-model-editor/sme_deps_common), as well as:

- [dune-copasi](https://gitlab.dune-project.org/copasi/dune-copasi)

Get the latest versions here:

- linux (gcc 9 / Ubuntu 18.04): [sme_deps_linux.tgz](https://github.com/spatial-model-editor/sme_deps/releases/latest/download/sme_deps_linux.tgz)
- osx (Apple clang 12 / macOS 10.15): [sme_deps_osx.tgz](https://github.com/spatial-model-editor/sme_deps/releases/latest/download/sme_deps_osx.tgz)
- win32 (mingw-w64-i686-gcc 10): [sme_deps_win32.tgz](https://github.com/spatial-model-editor/sme_deps/releases/latest/download/sme_deps_win32-mingw.tgz)
- win64 (mingw-w64-x86_64-gcc 10): [sme_deps_win64.tgz](https://github.com/spatial-model-editor/sme_deps/releases/latest/download/sme_deps_win64-mingw.tgz)

## Updating this repo

Any tagged commit will result in a github release.

To make a new release, update the library version numbers in [release.yml](https://github.com/spatial-model-editor/sme_deps/blob/master/.github/workflows/release.yml#L6) (and the build script [build.sh](https://github.com/spatial-model-editor/sme_deps/blob/master/build.sh) if necessary), then commit the changes:

```
git commit -am "revision update"
git push
```

This will trigger GitHub Action builds which will compile the libraries. If the builds are sucessful, tag this commit and push the tag to github:

```
git tag <tagname>
git push origin <tagname>
```

The tagged commit will trigger the builds again, but this time they will each add an archive of the resulting static libraries to the `<tagname>` release on this github repo.
