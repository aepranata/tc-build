#!/usr/bin/env bash
# Build Examples untuk Atiga Clang Toolchain
# Berbagai contoh konfigurasi build dengan kombinasi optimisasi

# Warna untuk output
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

msg() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Konfigurasi dasar
DIR="$(pwd)"
INSTALL_DIR="$DIR/install"
SRC_DIR="$DIR/src"
LINUX_SRC="$SRC_DIR/X00TD"
MLGO_MODEL=""  # Set path ke MLGO model jika ada

# Fungsi untuk build dasar
build_basic() {
    header "Build 1: Basic Build (Paling Cepat)"
    msg "Waktu estimasi: 30-60 menit"
    msg "RAM: ~8GB"
    msg "Performa: Baseline"
    
    ./build-llvm.py \
        --build-stage1-only \
        --install-folder "$INSTALL_DIR-basic" \
        --vendor-string "Atiga-Basic" \
        --targets ARM AArch64 X86 \
        2>&1 | tee build-basic.log
}

# Fungsi untuk build dengan ThinLTO
build_lto() {
    header "Build 2: ThinLTO Build"
    msg "Waktu estimasi: 2-3 jam"
    msg "RAM: ~16GB"
    msg "Performa: +3-5%"
    
    ./build-llvm.py \
        --lto thin \
        --defines LLVM_PARALLEL_COMPILE_JOBS="$(nproc)" LLVM_PARALLEL_LINK_JOBS="$(nproc)" \
        --install-folder "$INSTALL_DIR-lto" \
        --vendor-string "Atiga-LTO" \
        --targets ARM AArch64 X86 \
        --quiet-cmake \
        2>&1 | tee build-lto.log
}

# Fungsi untuk build dengan PGO
build_pgo() {
    header "Build 3: PGO Build"
    msg "Waktu estimasi: 4-6 jam"
    msg "RAM: ~16GB"
    msg "Performa: +15-20%"
    
    if [ ! -d "$LINUX_SRC" ]; then
        warn "Linux source tidak ditemukan di $LINUX_SRC"
        warn "Build akan mendownload kernel source otomatis"
    fi
    
    ./build-llvm.py \
        --pgo kernel-defconfig-slim \
        --linux-folder "$LINUX_SRC" \
        --defines LLVM_PARALLEL_COMPILE_JOBS="$(nproc)" LLVM_PARALLEL_LINK_JOBS="$(nproc)" \
        --install-folder "$INSTALL_DIR-pgo" \
        --vendor-string "Atiga-PGO" \
        --targets ARM AArch64 X86 \
        --quiet-cmake \
        2>&1 | tee build-pgo.log
}

# Fungsi untuk build dengan BOLT
build_bolt() {
    header "Build 4: BOLT Build"
    msg "Waktu estimasi: 3-4 jam"
    msg "RAM: ~16GB"
    msg "Performa: +5-7%"
    
    # Cek apakah perf bisa digunakan
    if perf record --branch-filter any,u --event cycles:u --output /dev/null -- sleep 1 2>/dev/null; then
        msg "Perf tersedia - menggunakan sampling mode (lebih cepat)"
    else
        warn "Perf tidak tersedia - akan menggunakan instrumentation mode (lebih lambat)"
    fi
    
    ./build-llvm.py \
        --bolt \
        --linux-folder "$LINUX_SRC" \
        --defines LLVM_PARALLEL_COMPILE_JOBS="$(nproc)" LLVM_PARALLEL_LINK_JOBS="$(nproc)" \
        --install-folder "$INSTALL_DIR-bolt" \
        --vendor-string "Atiga-BOLT" \
        --targets ARM AArch64 X86 \
        --quiet-cmake \
        2>&1 | tee build-bolt.log
}

# Fungsi untuk build optimal (PGO + ThinLTO + BOLT)
build_optimal() {
    header "Build 5: Optimal Build (PGO + ThinLTO + BOLT)"
    msg "Waktu estimasi: 8-12 jam"
    msg "RAM: ~32GB"
    msg "Performa: +20-30%"
    msg "Kombinasi terbaik untuk performa maksimal"
    
    ./build-llvm.py \
        --pgo kernel-defconfig-slim \
        --lto thin \
        --bolt \
        --assertions \
        --linux-folder "$LINUX_SRC" \
        --defines LLVM_PARALLEL_COMPILE_JOBS="$(nproc)" LLVM_PARALLEL_LINK_JOBS="$(nproc)" CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 \
        --projects clang lld compiler-rt bolt polly \
        --install-folder "$INSTALL_DIR-optimal" \
        --vendor-string "Atiga-Optimal" \
        --targets ARM AArch64 X86 \
        --quiet-cmake \
        2>&1 | tee build-optimal.log
}

# Fungsi untuk build maximum (Semua optimisasi termasuk MLGO)
build_maximum() {
    header "Build 6: Maximum Build (Semua Optimisasi + MLGO)"
    msg "Waktu estimasi: 12-18 jam"
    msg "RAM: ~64GB"
    msg "Performa: +25-35%"
    msg "Build terbaik dengan semua optimisasi"
    
    if [ -z "$MLGO_MODEL" ] || [ ! -d "$MLGO_MODEL" ]; then
        error "MLGO model tidak ditemukan!"
        error "Set MLGO_MODEL di skrip ini atau skip MLGO"
        warn "Melanjutkan tanpa MLGO..."
        MLGO_FLAG=""
    else
        msg "Menggunakan MLGO model dari: $MLGO_MODEL"
        MLGO_FLAG="--mlgo $MLGO_MODEL"
    fi
    
    ./build-llvm.py \
        --pgo kernel-defconfig kernel-allmodconfig-slim \
        --lto thin \
        --bolt \
        --assertions \
        $MLGO_FLAG \
        --linux-folder "$LINUX_SRC" \
        --defines LLVM_PARALLEL_COMPILE_JOBS="$(nproc)" LLVM_PARALLEL_LINK_JOBS="$(nproc)" CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 \
        --projects clang lld compiler-rt bolt polly \
        --install-folder "$INSTALL_DIR-maximum" \
        --vendor-string "Atiga-Maximum" \
        --targets ARM AArch64 X86 \
        --quiet-cmake \
        2>&1 | tee build-maximum.log
}

# Fungsi untuk build distribusi (untuk rilis)
build_distribution() {
    header "Build 7: Distribution Build (Untuk Rilis)"
    msg "Waktu estimasi: 10-14 jam"
    msg "RAM: ~32GB"
    msg "Build yang siap untuk didistribusikan"
    
    ./build-llvm.py \
        --pgo kernel-defconfig-slim \
        --lto thin \
        --bolt \
        --assertions \
        --linux-folder "$LINUX_SRC" \
        --defines LLVM_PARALLEL_COMPILE_JOBS="$(nproc)" LLVM_PARALLEL_LINK_JOBS="$(nproc)" CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 \
        --projects clang lld compiler-rt bolt polly \
        --install-folder "$INSTALL_DIR" \
        --vendor-string "Atiga" \
        --targets ARM AArch64 X86 \
        --quiet-cmake \
        2>&1 | tee build-distribution.log
    
    if [ $? -eq 0 ]; then
        msg "Build berhasil! Menjalankan build binutils..."
        ./build-binutils.py \
            --install-folder "$INSTALL_DIR" \
            --targets arm aarch64 x86_64
        
        msg "Membersihkan file yang tidak perlu..."
        rm -fr "$INSTALL_DIR/include"
        rm -f "$INSTALL_DIR/lib/"*.a "$INSTALL_DIR/lib/"*.la
        
        msg "Stripping binaries..."
        for f in $(find "$INSTALL_DIR" -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
            strip -s "${f::-1}" 2>/dev/null || true
        done
        
        header "Build Distribution Selesai!"
        msg "Toolchain tersedia di: $INSTALL_DIR"
    fi
}

# Fungsi untuk menampilkan menu
show_menu() {
    clear
    header "Atiga Clang Toolchain - Build Examples"
    echo "Pilih jenis build yang ingin dilakukan:"
    echo ""
    echo "1) Basic Build          - Paling cepat, performa baseline (30-60 menit)"
    echo "2) ThinLTO Build        - Build dengan LTO, +3-5% performa (2-3 jam)"
    echo "3) PGO Build            - Build dengan PGO, +15-20% performa (4-6 jam)"
    echo "4) BOLT Build           - Build dengan BOLT, +5-7% performa (3-4 jam)"
    echo "5) Optimal Build        - PGO+LTO+BOLT, +20-30% performa (8-12 jam)"
    echo "6) Maximum Build        - Semua optimisasi+MLGO, +25-35% performa (12-18 jam)"
    echo "7) Distribution Build   - Build untuk rilis (10-14 jam)"
    echo ""
    echo "8) Build Semua          - Jalankan semua build di atas (sangat lama!)"
    echo "9) Keluar"
    echo ""
}

# Main script
main() {
    if [ ! -f "build-llvm.py" ]; then
        error "build-llvm.py tidak ditemukan!"
        error "Pastikan Anda berada di direktori tc-build"
        exit 1
    fi
    
    # Make executable
    chmod +x build-llvm.py build-binutils.py 2>/dev/null || true
    
    while true; do
        show_menu
        read -p "Masukkan pilihan [1-9]: " choice
        
        case $choice in
            1)
                build_basic
                ;;
            2)
                build_lto
                ;;
            3)
                build_pgo
                ;;
            4)
                build_bolt
                ;;
            5)
                build_optimal
                ;;
            6)
                build_maximum
                ;;
            7)
                build_distribution
                ;;
            8)
                warn "Ini akan memakan waktu SANGAT LAMA (beberapa hari)!"
                read -p "Apakah Anda yakin? [y/N]: " confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    build_basic
                    build_lto
                    build_pgo
                    build_bolt
                    build_optimal
                    build_maximum
                    build_distribution
                fi
                ;;
            9)
                msg "Keluar..."
                exit 0
                ;;
            *)
                error "Pilihan tidak valid!"
                sleep 2
                ;;
        esac
        
        if [ $? -eq 0 ]; then
            msg "Build selesai!"
        else
            error "Build gagal! Cek log untuk detail error"
        fi
        
        echo ""
        read -p "Tekan Enter untuk kembali ke menu..."
    done
}

# Jalankan main jika dieksekusi langsung
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
