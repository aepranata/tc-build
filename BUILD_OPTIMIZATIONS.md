# Build Optimizations Guide

Panduan ini menjelaskan berbagai teknik optimisasi yang tersedia dalam build system untuk meningkatkan performa toolchain LLVM/Clang.

## Optimisasi yang Tersedia

### 1. BOLT (Binary Optimization and Layout Tool)

**Apa itu BOLT?**
BOLT adalah tool optimisasi binary yang dapat meningkatkan performa compile time sekitar 5-7% rata-rata dengan melakukan optimisasi pada binary clang yang sudah jadi.

**Cara Penggunaan:**
```bash
./build-llvm.py --bolt
```

**Catatan:**
- BOLT memerlukan `perf` untuk sampling atau akan menggunakan instrumentasi
- Jika menggunakan instrumentasi dengan PGO tanpa assertions, tambahkan `--assertions`
- Paling optimal pada arsitektur x86_64

**Contoh dengan kombinasi lain:**
```bash
./build-llvm.py --bolt --pgo kernel-defconfig-slim --assertions
```

---

### 2. PGO (Profile-Guided Optimization)

**Apa itu PGO?**
PGO meningkatkan performa compile time sekitar 15-20% rata-rata dengan menggunakan profile data dari kompilasi sebenarnya.

**Cara Penggunaan:**
```bash
# Menggunakan kernel defconfig untuk profiling
./build-llvm.py --pgo kernel-defconfig-slim

# Atau menggunakan beberapa konfigurasi kernel
./build-llvm.py --pgo kernel-defconfig kernel-allmodconfig

# Atau menggunakan LLVM itu sendiri sebagai benchmark
./build-llvm.py --pgo llvm
```

**Benchmark yang Tersedia:**
- `kernel-defconfig` - Build semua target dengan defconfig
- `kernel-defconfig-slim` - Build satu target saja (lebih cepat)
- `kernel-allmodconfig` - Build dengan allmodconfig
- `kernel-allmodconfig-slim` - Build satu target allmodconfig
- `kernel-allyesconfig` - Build dengan allyesconfig
- `kernel-allyesconfig-slim` - Build satu target allyesconfig
- `llvm` - Menggunakan LLVM build sebagai profiling

**Catatan:**
- PGO memerlukan lebih banyak waktu build (4-5x lipat)
- Memerlukan ruang disk minimal 25GB
- Tidak bisa digunakan dengan `--build-stage1-only`

---

### 3. LTO (Link-Time Optimization)

**Apa itu LTO?**
LTO meningkatkan performa compile time sekitar 3-5% rata-rata dengan melakukan optimisasi saat linking.

**Cara Penggunaan:**
```bash
# ThinLTO (Direkomendasikan)
./build-llvm.py --lto thin

# Full LTO (Memerlukan >64GB RAM)
./build-llvm.py --lto full
```

**ThinLTO vs Full LTO:**
- **ThinLTO**: 
  - Lebih cepat (fully multithreaded)
  - Memerlukan lebih sedikit RAM
  - Performa hampir sama dengan Full LTO (dalam 1%)
  - **Direkomendasikan untuk kebanyakan user**
  
- **Full LTO**:
  - Sangat lambat
  - Memerlukan >64GB RAM
  - Hanya untuk server dengan spesifikasi tinggi

**Catatan:**
- Waktu build ThinLTO sekitar 3.5x lipat dari default build
- Dengan PGO, waktu build bisa mencapai 9-10x lipat

---

### 4. MLGO (Machine Learning Guided Optimization)

**Apa itu MLGO?**
MLGO menggunakan machine learning untuk memandu keputusan optimisasi compiler, terutama untuk inlining decisions dan code generation.

**Cara Penggunaan:**
```bash
# Download model MLGO terlebih dahulu
# Dari: https://github.com/google/ml-compiler-opt

./build-llvm.py --mlgo /path/to/mlgo/model
```

**Persyaratan:**
- TensorFlow C API harus terinstall di sistem
- Model MLGO yang sudah dilatih
- Model harus dalam format TensorFlow SavedModel

**Mendapatkan Model MLGO:**
1. Clone repositori: `git clone https://github.com/google/ml-compiler-opt`
2. Ikuti instruksi untuk download atau train model
3. Gunakan path ke model saat build

**Link Referensi:**
- https://llvm.org/docs/OptimizingMLGO.html
- https://github.com/google/ml-compiler-opt

---

## Kombinasi Optimisasi

Anda dapat mengkombinasikan berbagai optimisasi untuk hasil terbaik:

### Kombinasi Rekomendasi

#### 1. Build Optimal (Waktu Sedang)
```bash
./build-llvm.py \
    --pgo kernel-defconfig-slim \
    --lto thin \
    --bolt \
    --assertions
```
**Performa:** +20-25% compile time improvement  
**Waktu Build:** ~6-8 jam (tergantung hardware)  
**RAM:** ~32GB

#### 2. Build Maximum (Waktu Lama)
```bash
./build-llvm.py \
    --pgo kernel-defconfig kernel-allmodconfig \
    --lto thin \
    --bolt \
    --mlgo /path/to/model \
    --assertions
```
**Performa:** +25-30% compile time improvement  
**Waktu Build:** ~10-15 jam  
**RAM:** ~64GB

#### 3. Build Quick (Waktu Cepat)
```bash
./build-llvm.py \
    --lto thin
```
**Performa:** +3-5% compile time improvement  
**Waktu Build:** ~2-3 jam  
**RAM:** ~16GB

#### 4. Build Slim (Testing)
```bash
./build-llvm.py \
    --build-stage1-only
```
**Performa:** Baseline  
**Waktu Build:** ~30-60 menit  
**RAM:** ~8GB

---

## Penggunaan dalam atiga.sh

File `atiga.sh` sudah dikonfigurasi dengan kombinasi optimal:

```bash
# Edit atiga.sh untuk mengaktifkan MLGO
MLGO_MODEL_PATH="/path/to/your/mlgo/model"

# Jalankan build
./atiga.sh
```

Build default di `atiga.sh` menggunakan:
- PGO dengan kernel-defconfig-slim
- BOLT
- ThinLTO
- Custom vendor string "Atiga"

---

## Tips dan Trik

### 1. Disk Space
Pastikan Anda memiliki cukup ruang disk:
- Build dasar: ~10GB
- Dengan PGO: ~25GB
- Dengan PGO + BOLT: ~30GB
- Dengan semua optimisasi: ~40GB

### 2. Memory Requirements
- Build dasar: 8GB RAM
- Dengan ThinLTO: 16GB RAM
- Dengan PGO + ThinLTO: 32GB RAM
- Dengan Full LTO: 64GB+ RAM

### 3. CPU Cores
Gunakan semua core untuk parallel compilation:
```bash
./build-llvm.py \
    --defines LLVM_PARALLEL_COMPILE_JOBS=$(nproc) \
              LLVM_PARALLEL_LINK_JOBS=$(nproc)
```

### 4. Ccache
Untuk mempercepat rebuild stage 1:
```bash
# Ccache aktif secara default, disable jika perlu:
./build-llvm.py --no-ccache
```

### 5. Linux Source untuk PGO/BOLT
Gunakan kernel source lokal untuk menghindari download berulang:
```bash
./build-llvm.py \
    --pgo kernel-defconfig-slim \
    --linux-folder /path/to/linux/source
```

---

## Troubleshooting

### BOLT Gagal dengan PGO
```bash
# Tambahkan --assertions
./build-llvm.py --bolt --pgo kernel-defconfig-slim --assertions
```

### Out of Memory saat LTO
```bash
# Gunakan ThinLTO bukan Full LTO
./build-llvm.py --lto thin

# Atau kurangi parallel jobs
./build-llvm.py --lto thin \
    --defines LLVM_PARALLEL_LINK_JOBS=2
```

### MLGO Model Tidak Ditemukan
```bash
# Pastikan path model benar dan direktori ada
ls -la /path/to/mlgo/model

# Model harus berupa direktori SavedModel, bukan file
```

### Perf Tidak Bisa Digunakan untuk BOLT
```bash
# Test apakah perf bisa digunakan:
perf record --branch-filter any,u --event cycles:u --output /dev/null -- sleep 1

# Jika gagal, BOLT akan menggunakan instrumentasi (lebih lambat)
```

---

## Referensi

- **BOLT**: https://github.com/llvm/llvm-project/tree/main/bolt
- **PGO**: https://llvm.org/docs/HowToBuildWithPGO.html
- **LTO**: https://llvm.org/docs/LinkTimeOptimization.html
- **ThinLTO**: https://clang.llvm.org/docs/ThinLTO.html
- **MLGO**: https://llvm.org/docs/OptimizingMLGO.html
- **ML Compiler Opt**: https://github.com/google/ml-compiler-opt

---

## Perbandingan Performa

| Konfigurasi | Compile Time Improvement | Build Time | RAM |
|-------------|-------------------------|------------|-----|
| Baseline | 0% | 1x | 8GB |
| LTO Thin | +3-5% | 3.5x | 16GB |
| PGO | +15-20% | 4-5x | 16GB |
| BOLT | +5-7% | 2x | 16GB |
| PGO + LTO | +18-25% | 9-10x | 32GB |
| PGO + LTO + BOLT | +20-30% | 10-12x | 32GB |
| All + MLGO | +25-35% | 12-15x | 64GB |

*Note: Angka performa bervariasi tergantung workload dan hardware*

---

Dibuat untuk Atiga Clang Toolchain Builder
