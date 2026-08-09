# MLGO Setup Guide - Auto-Detection

## 🎯 Overview

Script `atiga.sh` sekarang bisa **otomatis mendeteksi** MLGO model, mirip seperti `X00TD`!

Tidak perlu edit script lagi - cukup letakkan model di lokasi yang benar.

---

## 🚀 Quick Setup

### Option 1: Recommended (Auto-detected)

Letakkan MLGO model di salah satu lokasi ini (akan auto-detect):

```bash
# Priority 1: Di dalam src/mlgo-model
mkdir -p src/mlgo-model
cp -r /path/to/your/model/* src/mlgo-model/

# Priority 2: Di dalam src/ml-compiler-opt/model
mkdir -p src/ml-compiler-opt/model
cp -r /path/to/your/model/* src/ml-compiler-opt/model/

# Priority 3: Di root tc-build/mlgo-model
mkdir -p mlgo-model
cp -r /path/to/your/model/* mlgo-model/
```

Lalu langsung jalankan:
```bash
./atiga.sh
```

Script akan otomatis mendeteksi dan menggunakan MLGO!

### Option 2: Environment Variable

Set environment variable sebelum build:

```bash
export MLGO_MODEL_PATH="/custom/path/to/your/model"
./atiga.sh
```

---

## 📋 Detection Priority

Script akan mencari model dalam urutan ini:

1. **`$src/mlgo-model`** ← Highest priority
2. **`$src/ml-compiler-opt/model`**
3. **`$DIR/mlgo-model`**
4. **`$MLGO_MODEL_PATH`** (environment variable)
5. Jika tidak ada → Build tanpa MLGO (fallback ke PGO+LTO+BOLT)

---

## 📥 Download MLGO Model

### Method 1: Clone Repository

```bash
cd src/
git clone https://github.com/google/ml-compiler-opt
cd ml-compiler-opt

# Follow instructions to download pre-trained model
# Model biasanya di: ml-compiler-opt/model/
```

### Method 2: Download Pre-trained Model

```bash
# Download dari release (jika tersedia)
cd src/
mkdir -p mlgo-model
cd mlgo-model

# Download model files
# Contoh (sesuaikan dengan versi yang tersedia):
wget https://github.com/google/ml-compiler-opt/releases/download/v1.0/model.tar.gz
tar -xzf model.tar.gz
```

### Method 3: Train Your Own Model

```bash
# Clone ml-compiler-opt
git clone https://github.com/google/ml-compiler-opt
cd ml-compiler-opt

# Install dependencies
pip install -r requirements.txt

# Train model (memerlukan waktu lama dan GPU)
# Follow training guide di repository
```

---

## ✅ Verify Detection

Jalankan `atiga.sh` dan perhatikan output:

### Jika model ditemukan:
```
Using MLGO model from: /home/aepranata/atiga-clang/tc-build/src/mlgo-model
```

### Jika model tidak ditemukan:
```
MLGO model not found, building without MLGO optimization
To enable MLGO, place model in one of these locations:
  - /home/aepranata/atiga-clang/tc-build/src/mlgo-model
  - /home/aepranata/atiga-clang/tc-build/src/ml-compiler-opt/model
  - Or set: export MLGO_MODEL_PATH=/path/to/model
```

---

## 📁 Directory Structure

Struktur direktori yang direkomendasikan:

```
tc-build/
├── atiga.sh
├── build-llvm.py
├── src/
│   ├── llvm-project/
│   ├── X00TD/              ← Kernel source (sudah ada)
│   └── mlgo-model/         ← Letakkan MLGO model di sini ⭐
│       ├── saved_model.pb
│       ├── variables/
│       └── ...
└── install/
```

Atau:

```
tc-build/
├── atiga.sh
├── build-llvm.py
├── src/
│   ├── llvm-project/
│   ├── X00TD/
│   └── ml-compiler-opt/    ← Clone repository
│       ├── model/          ← Model akan auto-detect ⭐
│       │   ├── saved_model.pb
│       │   └── variables/
│       └── ...
└── install/
```

---

## 🔧 Manual Override

Jika Anda ingin menggunakan lokasi custom:

### Temporary (satu kali build):
```bash
export MLGO_MODEL_PATH="/custom/path/to/model"
./atiga.sh
```

### Permanent (edit atiga.sh):
```bash
# Edit baris ini di atiga.sh (setelah auto-detection):
MLGO_MODEL_PATH="/your/custom/path/to/model"
```

---

## 🧪 Testing Detection

Test apakah model terdeteksi tanpa build:

```bash
# Buat script test sederhana
cat << 'EOF' > test-mlgo-detection.sh
#!/usr/bin/env bash
DIR="$(pwd)"
src=$DIR/src

if [ -d "$src/mlgo-model" ]; then
    echo "✅ Found: $src/mlgo-model"
    MLGO_MODEL_PATH="$src/mlgo-model"
elif [ -d "$src/ml-compiler-opt/model" ]; then
    echo "✅ Found: $src/ml-compiler-opt/model"
    MLGO_MODEL_PATH="$src/ml-compiler-opt/model"
elif [ -d "$DIR/mlgo-model" ]; then
    echo "✅ Found: $DIR/mlgo-model"
    MLGO_MODEL_PATH="$DIR/mlgo-model"
else
    echo "❌ MLGO model not found"
    MLGO_MODEL_PATH=""
fi

if [ -n "$MLGO_MODEL_PATH" ]; then
    echo "MLGO will be enabled with: $MLGO_MODEL_PATH"
    ls -la "$MLGO_MODEL_PATH"
else
    echo "MLGO will be disabled"
fi
EOF

chmod +x test-mlgo-detection.sh
./test-mlgo-detection.sh
```

---

## 📝 Model Requirements

MLGO model harus dalam format:
- **TensorFlow SavedModel** format
- Harus berisi:
  - `saved_model.pb`
  - `variables/` directory
  - Compatible dengan LLVM MLGO

---

## 🎯 Comparison: X00TD vs MLGO Detection

Seperti yang Anda minta, sekarang MLGO auto-detect mirip X00TD:

### X00TD (Kernel Source):
```bash
# atiga.sh
--linux-folder "$src/X00TD"    # Auto dari variabel $src
```

### MLGO (Model):
```bash
# atiga.sh - sekarang juga auto!
# Cek di: $src/mlgo-model
# Atau:   $src/ml-compiler-opt/model
# Atau:   $DIR/mlgo-model
# AUTO DETECTED! 🎉
```

---

## ❓ FAQ

### Q: Apakah MLGO wajib?
**A:** Tidak! Jika model tidak ditemukan, build tetap jalan dengan PGO+LTO+BOLT (masih dapat +20-30% improvement).

### Q: Dimana download model pre-trained?
**A:** https://github.com/google/ml-compiler-opt/releases (jika tersedia), atau train sendiri.

### Q: Berapa besar MLGO model?
**A:** Biasanya 50-500 MB tergantung model.

### Q: Apakah model perlu di-update?
**A:** Model bisa digunakan untuk beberapa versi LLVM, tapi model yang lebih baru biasanya lebih optimal.

### Q: Apakah bisa menggunakan multiple models?
**A:** Tidak, script hanya menggunakan satu model (yang pertama ditemukan sesuai priority).

---

## 🚨 Troubleshooting

### Model tidak terdeteksi
```bash
# Cek apakah direktori ada
ls -la src/mlgo-model
ls -la src/ml-compiler-opt/model

# Cek isi model
ls -la src/mlgo-model/
# Harus ada: saved_model.pb, variables/
```

### Build error: "MLGO model path does not exist"
```bash
# Model path ditemukan tapi isinya tidak valid
# Pastikan model berisi saved_model.pb
ls -la $MLGO_MODEL_PATH/saved_model.pb
```

### Model terdeteksi tapi build gagal
```bash
# Mungkin TensorFlow C API belum terinstall
# Install TensorFlow C API terlebih dahulu
```

---

## 🎉 Summary

**Sekarang setup MLGO semudah X00TD!**

1. Download/clone MLGO model
2. Letakkan di `src/mlgo-model/`
3. Jalankan `./atiga.sh`
4. Done! Auto-detect dan auto-enable MLGO ✅

Tidak perlu edit script lagi!

---

**Created**: 2026-08-03  
**Author**: Kiro AI Assistant  
**For**: Atiga Clang Build System
