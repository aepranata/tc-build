#!/usr/bin/env bash

set -eo pipefail

#export CC=$HOME/tools/atiga/bin/clang
#export CXX=$HOME/tools/atiga/bin/clang++
export install=$HOME/build/clang

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$@\e[0m"
}

# Don't touch repo if running on CI
[ -z "$GH_RUN_ID" ] && repo_flag="--shallow-clone" || repo_flag="--no-update"

# Build LLVM
msg "Building LLVM..."
./build-llvm.py \
	--vendor-string "Banana" \
	--targets ARM AArch64 X86 \
    --show-build-commands \
    --install-folder "$install" \
	--lto full

# Build binutils
msg "Building binutils..."
./build-binutils.py --targets arm aarch64 x86_64 --show-build-commands --install-folder "$install"

# Remove unused products
msg "Removing unused products..."
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip ${f: : -1}
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
msg "Setting library load paths for portability..."
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath '$ORIGIN/../lib' "$bin"
done
