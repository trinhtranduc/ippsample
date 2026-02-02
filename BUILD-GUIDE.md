# Hướng dẫn Build IPP Sample Code - Chi tiết

## 📋 Tổng quan

Hướng dẫn build IPP Sample Code (ippserver, ipptool, etc.) cho ARM64 trên macOS, bao gồm cách fix code signature issues.

## 🎯 Mục tiêu

- Build IPP Sample Code cho ARM64 only
- Fix code signature issues với Homebrew libraries
- Cài đặt vào thư mục local (không cần sudo)

## 🧹 Bước 1: Clear Build (Nếu cần rebuild)

### 1.1. Clean build artifacts

```bash
cd "/Users/trinhtran/Documents/Source Code/ippexample"

# Clean build files
make clean

# Clean configure artifacts
make distclean

# Hoặc clean toàn bộ
rm -rf Makedefs config.h config.log config.status autom4te*.cache
```

### 1.2. Clean submodules

```bash
# Clean libcups
cd libcups
make distclean
cd ..

# Clean install directory (nếu muốn reinstall)
rm -rf ~/local/bin/ipp* ~/local/sbin/ipp* ~/local/lib/libcups* ~/local/lib/libpdfio*
```

### 1.3. Clean environment

```bash
# Unset build variables
unset CFLAGS LDFLAGS CPPFLAGS
```

## 🔧 Bước 2: Fix Code Signature Issues

### Vấn đề

Build với Homebrew libraries (OpenSSL, libpng) gây ra code signature issues:
```
dyld: Library not loaded: /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib
Reason: code signature not valid for use in process
```

### Giải pháp: Dùng System Libraries

macOS có sẵn OpenSSL và các libraries khác trong system. Cần configure để dùng system libraries thay vì Homebrew.

### 2.1. Kiểm tra system libraries

```bash
# Kiểm tra system OpenSSL
ls -la /usr/lib/libssl* /usr/lib/libcrypto* 2>/dev/null

# Kiểm tra system libpng
ls -la /usr/lib/libpng* 2>/dev/null

# Hoặc dùng pkg-config để tìm
pkg-config --libs openssl 2>/dev/null || echo "Không tìm thấy system OpenSSL"
```

### 2.2. Configure với system libraries

**Option 1: Dùng system OpenSSL (nếu có)**

```bash
export CFLAGS="-arch arm64"
export LDFLAGS="-arch arm64"

# Nếu system có OpenSSL
export CPPFLAGS="-I/usr/include"
export LDFLAGS="-arch arm64 -L/usr/lib"

./configure --disable-shared
```

**Option 2: Build static libraries (khuyến nghị)**

Build static để tránh dependency issues:

```bash
export CFLAGS="-arch arm64"
export LDFLAGS="-arch arm64"

./configure --disable-shared --enable-static
make
```

**Option 3: Rebuild Homebrew libraries với proper signature**

Nếu vẫn muốn dùng Homebrew libraries:

```bash
# Reinstall OpenSSL với proper signature
brew reinstall openssl@3

# Hoặc dùng system OpenSSL
brew unlink openssl@3
```

## 🏗️ Bước 3: Build từ đầu

### 3.1. Setup environment variables

```bash
cd "/Users/trinhtran/Documents/Source Code/ippexample"

# Set architecture
export CFLAGS="-arch arm64"
export LDFLAGS="-arch arm64"

# Optional: Nếu muốn dùng system libraries
# export CPPFLAGS="-I/usr/include"
# export LDFLAGS="-arch arm64 -L/usr/lib"
```

### 3.2. Configure

```bash
# Configure với static libraries (khuyến nghị)
./configure --disable-shared --enable-static

# Hoặc chỉ disable shared
./configure --disable-shared
```

### 3.3. Build

```bash
make
```

### 3.4. Fix đường dẫn có khoảng trắng (nếu cần)

Sau khi configure, sửa các file `Makedefs` nếu có đường dẫn có khoảng trắng:

```bash
# Sửa Makedefs ở root
sed -i '' 's|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	"/Users/trinhtran/Documents/Source Code/ippexample/install-sh"|' Makedefs

# Sửa libcups/Makedefs
sed -i '' 's|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	"/Users/trinhtran/Documents/Source Code/ippexample/libcups/install-sh"|' libcups/Makedefs

# Sửa libcups/pdfio/Makefile
sed -i '' 's|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	"/Users/trinhtran/Documents/Source Code/ippexample/libcups/pdfio/install-sh"|' libcups/pdfio/Makefile

# Sửa CUPS_DATADIR trong libcups/Makedefs
sed -i '' 's|^CUPS_DATADIR[[:space:]]*=.*|CUPS_DATADIR\t=	${prefix}/share/libcups3|' libcups/Makedefs
```

### 3.5. Install

```bash
make install prefix="$HOME/local"
```

## ✅ Bước 4: Verify Build

### 4.1. Kiểm tra binaries

```bash
# Setup environment
source ~/Documents/Source\ Code/ippexample/setup-local-env.sh

# Kiểm tra tools
which ippserver ipptool ippproxy

# Kiểm tra version
ippserver --version
```

### 4.2. Test code signature

```bash
# Kiểm tra dependencies
otool -L ~/local/bin/ipptool | grep -E "ssl|png"

# Test chạy (không nên có lỗi code signature)
~/local/bin/ipptool --version 2>&1
```

### 4.3. Test ippserver

```bash
# Test ippserver có chạy được không
~/local/sbin/ippserver --version

# Test start server
cd test-ippserver
./start-server.sh &
sleep 2
ps aux | grep ippserver | grep -v grep
```

## 🔍 Troubleshooting

### Vấn đề 1: Vẫn có code signature errors

**Giải pháp:**
1. Rebuild với `--enable-static` để tạo static binaries
2. Hoặc dùng system libraries thay vì Homebrew
3. Hoặc code sign binaries với proper certificate

### Vấn đề 2: Không tìm thấy system libraries

**Giải pháp:**
- macOS có thể không có OpenSSL trong `/usr/lib/`
- Có thể cần install qua Homebrew nhưng rebuild với proper signature
- Hoặc build static để tránh dependencies

### Vấn đề 3: Build fails với system libraries

**Giải pháp:**
- Quay lại dùng Homebrew libraries
- Build static (`--enable-static`)
- Accept code signature issues và dùng workaround (không khuyến nghị)

## 📝 Quick Reference

### Clean và rebuild hoàn toàn:

```bash
cd "/Users/trinhtran/Documents/Source Code/ippexample"

# Clean
make distclean
cd libcups && make distclean && cd ..

# Setup
export CFLAGS="-arch arm64"
export LDFLAGS="-arch arm64"

# Configure và build
./configure --disable-shared --enable-static
make

# Fix paths (nếu cần)
# ... (xem bước 3.4)

# Install
make install prefix="$HOME/local"
```

### Rebuild chỉ một phần:

```bash
# Clean một module
cd libcups
make clean
make

# Rebuild và reinstall
cd ..
make clean
make
make install prefix="$HOME/local"
```

## 🎯 Best Practices

1. **Luôn build static** (`--enable-static`) để tránh dependency issues
2. **Fix paths ngay sau configure** để tránh lỗi install
3. **Test ngay sau build** để phát hiện issues sớm
4. **Giữ build logs** để debug nếu có vấn đề

## 📚 Tài liệu liên quan

- `BUILD-SUMMARY.md` - Tổng hợp quá trình build ban đầu
- `README.md` - Tài liệu chính của project
- `BUILD.md` - Hướng dẫn build từ project
- `test-ippserver/TEST-GUIDE.md` - Hướng dẫn test

## 🔄 Update History

- **2025-01-22**: Thêm hướng dẫn clear build và fix code signature issues
