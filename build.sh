#!/bin/bash

set -e -x

export PATH="/usr/local/opt/llvm/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/llvm/lib"
export CPPFLAGS="-I/usr/local/opt/llvm/include"

clang++ --version

clang++ -o x test.cpp -std=c++20 -L/usr/local/opt/llvm/lib/c++ -Wl,-rpath,/usr/local/opt/llvm/lib/c++

/usr/local/opt/llvm/bin/clang++ -o x test.cpp -std=c++20 -L/usr/local/opt/llvm/lib/c++ -static-libstdc++ -I/usr/local/opt/llvm/include -L/usr/local/opt/llvm/lib

ls

otool -L x
