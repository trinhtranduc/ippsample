# Vấn đề OpenSSL và Code Signature trên macOS

## 🔍 Vấn đề

### Tại sao liên quan đến Homebrew?

1. **macOS không có system OpenSSL**
   - Apple deprecated OpenSSL từ macOS 10.15+
   - `/usr/lib/libssl*` không còn tồn tại
   - macOS chỉ có Security framework (không tương thích với OpenSSL API)

2. **Build system tự động tìm OpenSSL qua pkg-config**
   ```bash
   # Configure script trong libcups/configure.ac:
   AS_IF([$PKGCONFIG --exists openssl], [
       CPPFLAGS="$CPPFLAGS $($PKGCONFIG --cflags openssl)"
       LIBS="$LIBS $($PKGCONFIG --libs openssl)"
   ])
   ```

3. **pkg-config tìm thấy Homebrew OpenSSL**
   ```bash
   $ pkg-config --libs openssl
   -L/opt/homebrew/Cellar/openssl@3/3.6.0/lib -lssl -lcrypto
   ```

4. **Homebrew libraries có code signature issues**
   - Homebrew libraries được sign bởi Homebrew (Team ID khác)
   - macOS security block việc load libraries có signature không match
   - Lỗi: `code signature not valid for use in process`

## ✅ Giải pháp

### Option 1: Build OpenSSL Static (Khuyến nghị)

Build OpenSSL từ source và link static vào executables:

```bash
# 1. Clone và build OpenSSL static
cd ~/local/src
git clone https://github.com/openssl/openssl.git
cd openssl
./Configure darwin64-arm64-cc --prefix=$HOME/local/openssl-static --openssldir=$HOME/local/openssl-static/ssl no-shared
make
make install

# 2. Build ippexample với static OpenSSL
cd "/Users/trinhtran/Documents/Source Code/ippexample"
export CFLAGS="-arch arm64 -I$HOME/local/openssl-static/include"
export LDFLAGS="-arch arm64 -L$HOME/local/openssl-static/lib"
export PKG_CONFIG_PATH="$HOME/local/openssl-static/lib/pkgconfig:$PKG_CONFIG_PATH"

./configure --disable-shared --enable-static --with-tls=openssl
make
make install prefix="$HOME/local"
```

**Ưu điểm:**
- Không có code signature issues
- Fully static, không phụ thuộc external libraries
- Hoạt động độc lập

**Nhược điểm:**
- Build time lâu hơn
- Binary size lớn hơn

### Option 2: Dùng GnuTLS (Nếu có)

Nếu đã cài GnuTLS qua Homebrew:

```bash
brew install gnutls

cd "/Users/trinhtran/Documents/Source Code/ippexample"
export CFLAGS="-arch arm64"
export LDFLAGS="-arch arm64"

./configure --disable-shared --enable-static --with-tls=gnutls
make
make install prefix="$HOME/local"
```

**Ưu điểm:**
- Không cần build OpenSSL
- GnuTLS có thể ít code signature issues hơn

**Nhược điểm:**
- Cần cài GnuTLS
- Có thể vẫn có code signature issues với Homebrew GnuTLS

### Option 3: Accept Homebrew và Handle Code Signature

Giữ nguyên build hiện tại và handle code signature issues:

```bash
# Code sign binaries sau khi install
codesign --force --deep --sign - ~/local/bin/ipptool
codesign --force --deep --sign - ~/local/sbin/ippserver
# ... (cho tất cả binaries)
```

**Ưu điểm:**
- Đơn giản, không cần rebuild OpenSSL

**Nhược điểm:**
- Vẫn có thể gặp issues với Homebrew libraries
- Không giải quyết root cause

### Option 4: Dùng System Security Framework (Không khả thi)

**Không thể:** libcups không support dùng Security framework thay OpenSSL
- Code chỉ include `Security.h` cho certificate store
- TLS implementation vẫn cần OpenSSL/GnuTLS

## 🎯 Khuyến nghị

**Dùng Option 1 (Build OpenSSL Static)** vì:
1. Giải quyết hoàn toàn code signature issues
2. Tạo fully static binaries
3. Không phụ thuộc Homebrew
4. Phù hợp cho production use

## 📝 Script tự động

Script `build-with-static-openssl.sh` đã được tạo để tự động build OpenSSL static và rebuild ippexample:

```bash
# Chạy script
cd "/Users/trinhtran/Documents/Source Code/ippexample"
./build-with-static-openssl.sh
```

Script sẽ:
1. ✅ Clone/build OpenSSL static từ source
2. ✅ Clean ippexample build
3. ✅ Configure với static OpenSSL
4. ✅ Build và install ippexample
5. ✅ Verify binaries (không có Homebrew dependencies)

**Lưu ý:** 
- Build OpenSSL có thể mất 10-20 phút
- Cần ~500MB disk space cho OpenSSL source + build
- Script tự động detect và fix paths có spaces
