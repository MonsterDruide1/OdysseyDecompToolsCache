#!/usr/bin/env bash

function build_llvm_binaries {

    COMMON_CMAKE_ARGS=(
        -GNinja
        -DCMAKE_BUILD_TYPE=Release
        -DLLVM_BUILD_TESTS=OFF
        -DLLVM_INCLUDE_TESTS=OFF
        -DLLVM_BUILD_EXAMPLES=OFF
        -DLLVM_INCLUDE_EXAMPLES=OFF
        -DLLVM_BUILD_DOCS=OFF
        -DLLVM_ENABLE_SPHINX=OFF
        -DLLVM_ENABLE_DOXYGEN=OFF
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    )

    if [ -f "cfe-3.9.1.src/build/bin/clang-3.9" ] && [ -f "lld-3.9.1.src/build/tools/lld/lld" ]; then
        return
    fi

    if ! python --version 2>&1 | grep -q "2\.7" && ! command -v python2.7 >/dev/null; then
        echo "Python 2.7 is required for building llvm, but was not found"
        exit 1
    fi

    # Download llvm 3.9.1 src
    if [ ! -f "llvm-3.9.1.src.tar.xz" ]; then
        curl -O https://releases.llvm.org/3.9.1/llvm-3.9.1.src.tar.xz
    fi

    # Extract llvm 3.9.1 src
    if [ ! -d "llvm-3.9.1.src" ]; then
        tar xf llvm-3.9.1.src.tar.xz
    fi

    # Build llvm 3.9.1
    cmake "${COMMON_CMAKE_ARGS[@]}" -S llvm-3.9.1.src -B llvm-3.9.1.src/build
    ninja -C llvm-3.9.1.src/build

    # Download clang 3.9.1 src
    if [ ! -f "cfe-3.9.1.src.tar.xz" ]; then
        curl -O https://releases.llvm.org/3.9.1/cfe-3.9.1.src.tar.xz
    fi

    # Extract and patch clang 3.9.1 src
    if [ ! -d "cfe-3.9.1.src" ]; then
        tar xf cfe-3.9.1.src.tar.xz
        pushd cfe-3.9.1.src
        patch -p1 < ../../patches/clang-391-compile-fix.patch
        popd
    fi

    # Build clang 3.9.1
    cmake "${COMMON_CMAKE_ARGS[@]}" -DLLVM_CONFIG=$(pwd)/llvm-3.9.1.src/build/bin/llvm-config -S cfe-3.9.1.src -B cfe-3.9.1.src/build
    ninja -C cfe-3.9.1.src/build

    # Download lld 3.9.1 src
    if [ ! -f "lld-3.9.1.src.tar.xz" ]; then
        curl -O https://releases.llvm.org/3.9.1/lld-3.9.1.src.tar.xz
    fi

    # Extract and patch lld 3.9.1 src
    if [ ! -d "lld-3.9.1.src" ]; then
        tar xf lld-3.9.1.src.tar.xz
        pushd lld-3.9.1.src
        patch -p1 < ../../patches/lld-3.9.1-standalone.patch
        popd
    fi

    # Build lld 3.9.1
    cmake "${COMMON_CMAKE_ARGS[@]}" -DLLVM_SRC_DIR=$(pwd)/llvm-3.9.1.src -DCMAKE_PREFIX_PATH=$(pwd)/llvm-3.9.1.src/build -DPACKAGE_VERSION="3.9.1" -S lld-3.9.1.src -B lld-3.9.1.src/build
    ninja -C lld-3.9.1.src/build
}

function build_viking_tools {
    pushd nx-decomp-tools/viking
    cargo build --release
    popd
}

function build_linter {
    pushd OdysseyDecompLinter
    cargo build --release
    popd
}

function build_nx2elf {
    if [ ! -f "nx2elf/nx2elf" ]; then
        pushd nx2elf
        # Use clang with different compiler args on macos
        if uname -s | grep -q "Darwin" ; then
        clang++ -o nx2elf *.cpp *.c -std=c++17
        else
        make
        fi
        popd
    fi
}

function build_archives {
    OS=$(uname -s)
    ARCH=$(uname -m)
    BIN_OUT_NAME="OdysseyDecomp-binaries_$ARCH-$OS"

    # Create folder skeleton
    mkdir -p build/$BIN_OUT_NAME/bin

    # Copy clang 3.9.1
    cp download/cfe-3.9.1.src/build/bin/clang-3.9 build/$BIN_OUT_NAME/bin/clang

    # Copy lld 3.9.1
    cp download/lld-3.9.1.src/build/tools/lld/lld build/$BIN_OUT_NAME/bin/ld.lld

    # Copy viking tools
    cp nx-decomp-tools/viking/target/release/check build/$BIN_OUT_NAME/bin/
    cp nx-decomp-tools/viking/target/release/listsym build/$BIN_OUT_NAME/bin/
    cp nx-decomp-tools/viking/target/release/decompme build/$BIN_OUT_NAME/bin/

    # Copy nx2elf
    cp nx2elf/nx2elf build/$BIN_OUT_NAME/bin/

    # Copy linter
    cp OdysseyDecompLinter/target/release/linter build/$BIN_OUT_NAME/bin/

    if [ "$1" == "--no-tarball" ]; then
        return
    fi

    # Create tools tarball
    pushd build/$BIN_OUT_NAME
    tar -cJf ../$BIN_OUT_NAME.tar.xz *
    popd
}

# Fail on first error
set -e

# create directory for files being downloaded
mkdir -p download

# Create/clear build directory
rm -rf build || true
mkdir build

build_linter

pushd download
build_llvm_binaries
popd

build_viking_tools

build_nx2elf

build_archives $1
