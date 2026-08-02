#!/usr/bin/env bash

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}
err() {
    echo -e "\e[1;41$*\e[0m"
}

# Environment Config
export BRANCH=main
export CACHE=1

# Get home directory
DIR="$(pwd)"
install=$DIR/install
src=$DIR/src

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Release Info
pushd "$src"/llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<<"$llvm_commit")"
popd || exit

llvm_commit_url="https://android.googlesource.com/toolchain/llvm-project.git/+/$short_llvm_commit"
binutils_ver="$(ls "$src" | grep "^binutils-" | grep -v ".tar" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

# Push to GitHub
# Update Git repository
if [ ! -d rel_repo ]; then
    git clone "git@github.com:aepranata/atiga-clang.git" rel_repo
fi
pushd rel_repo || exit
rm -fr ./*
cp -r ../install/* .
git lfs install
git lfs track "bugpoint"
git lfs track "c-index-test"
git lfs track "clang-21"
git lfs track "clang-installapi"
git lfs track "clang-linker-wrapper"
git lfs track "clang-nvlink-wrapper"
git lfs track "clang-refactor"
git lfs track "clang-repl"
git lfs track "clang-scan-deps"
git lfs track "dsymutil"
git lfs track "llc"
git lfs track "lld"
git lfs track "lli"
git lfs track "llvm-bolt"
git lfs track "llvm-bolt-binary-analysis"
git lfs track "llvm-bolt-heatmap"
git lfs track "llvm-c-test"
git lfs track "llvm-dwp"
git lfs track "llvm-exegesis"
git lfs track "llvm-gsymutil"
git lfs track "llvm-jitlink"
git lfs track "llvm-lto"
git lfs track "llvm-lto2"
git lfs track "llvm-reduce"
git lfs track "llvm-split"
git lfs track "opt"
git lfs track "libclang.so.21.0.0git"
git lfs track "libclang-cpp.so.21.0git"
git lfs track "libLTO.so.21.0git"
git checkout README.md # keep this as it's not part of the toolchain itself
git add .
git commit -asm "Nightcord: Update to $rel_date build
LLVM commit: $llvm_commit_url
Clang Version: $clang_version
Binutils version: $binutils_ver
Builder commit: https://github.com/aepranata/tc_build/commit/$builder_commit"
git push
popd || exit
