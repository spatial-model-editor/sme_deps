#!/bin/bash

set -e -x

#export PATH="/usr/local/opt/llvm/bin:$PATH"

/usr/local/opt/llvm/bin/clang++ -o x test.cpp -std=c++20 -L/usr/local/opt/llvm/lib/c++ -static-libstdc++ -I/usr/local/opt/llvm/include -L/usr/local/opt/llvm/lib

ls

otool -L x
