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

# Auto-detect MLGO Model Path (similar to X00TD detection)
# Priority order:
# 1. $src/mlgo-model
# 2. $src/ml-compiler-opt/model
# 3. $DIR/mlgo-model
# 4. Empty (MLGO disabled)
if [ -d "$src/mlgo-model" ]; then
    MLGO_MODEL_PATH="$src/mlgo-model"
elif [ -d "$src/ml-compiler-opt/model" ]; then
    MLGO_MODEL_PATH="$src/ml-compiler-opt/model"
elif [ -d "$DIR/mlgo-model" ]; then
    MLGO_MODEL_PATH="$DIR/mlgo-model"
else
    MLGO_MODEL_PATH=""
fi

# You can also manually override by setting environment variable:
# export MLGO_MODEL_PATH="/custom/path/to/model"
MLGO_MODEL_PATH="${MLGO_MODEL_PATH:-}"

# Build ID - counter yang increment tiap kali build
build_id_file="$DIR/.build_id"
[ -f "$build_id_file" ] || echo 0 > "$build_id_file"
build_id=$(date +%s)
echo "$build_id" > "$build_id_file"

llvm_tag="r563880c"

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Building LLVM's
msg "Building LLVM's ..."
chmod +x build-llvm.py

# Prepare build command
BUILD_CMD=(
    ./build-llvm.py
    --defines LLVM_PARALLEL_COMPILE_JOBS="$(nproc)" LLVM_PARALLEL_LINK_JOBS="$(nproc)" CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 LLVM_VERSION_SUFFIX=""
    --projects clang lld compiler-rt bolt polly
    --pgo kernel-defconfig-slim
    --bolt
    --lto thin
    --install-folder "$install"
    --linux-folder "$src/X00TD"
    --quiet-cmake
    --targets ARM AArch64 X86
    --no-update
    --vendor-string "Atiga ($build_id, +pgo, +bolt, +lto, based on $llvm_tag)"
)

# Add MLGO if model path is set and exists
if [ -n "$MLGO_MODEL_PATH" ] && [ -d "$MLGO_MODEL_PATH" ]; then
    msg "Using MLGO model from: $MLGO_MODEL_PATH"
    BUILD_CMD+=(--mlgo "$MLGO_MODEL_PATH")
else
    msg "MLGO model not found, building without MLGO optimization"
    msg "To enable MLGO, place model in one of these locations:"
    msg "  - $src/mlgo-model"
    msg "  - $src/ml-compiler-opt/model"
    msg "  - Or set: export MLGO_MODEL_PATH=/path/to/model"
fi

# Execute build
"${BUILD_CMD[@]}" 2>&1 | tee build.log

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-2* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
	err "build.log" "Error Log"
	exit 1
}

# Build binutils
msg "Build binutils ..."
chmod +x build-binutils.py
./build-binutils.py \
    --install-folder "$install" \
    --targets arm aarch64 x86_64

rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
    strip -s "${f::-1}"
done

for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
    bin="${bin::-1}"

    echo "$bin"
    patchelf --set-rpath "$DIR/../lib" "$bin"
done
