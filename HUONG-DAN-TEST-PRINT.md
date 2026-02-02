# 🖨️ Hướng dẫn Test ippserver và In PDF

## 📋 Tổng quan

Sau khi build thành công, bạn có thể test ippserver để in PDF. Hướng dẫn này sẽ giúp bạn:
1. Setup environment
2. Khởi động ippserver
3. Test in PDF

---

## 🚀 Bước 1: Setup Environment

Mở terminal và chạy:

```bash
cd "/Users/trinhtran/Documents/Source-Code/ippexample/test-ippserver"
source setup-local-env.sh
```

**Giải thích:**
- Script này sẽ thêm `~/local/bin` và `~/local/sbin` vào PATH
- Cho phép bạn chạy `ippserver`, `ipptool` từ bất kỳ đâu
- Có thể thêm vào `~/.zshrc` để tự động load mỗi lần mở terminal

**Kiểm tra tools đã sẵn sàng:**
```bash
which ippserver ipptool
ippserver --version
ipptool --version
```

---

## 🖥️ Bước 2: Khởi động ippserver

### Cách 1: Dùng script có sẵn (Khuyến nghị)

Mở terminal mới (giữ terminal setup environment) và chạy:

```bash
cd "/Users/trinhtran/Documents/Source-Code/ippexample/test-ippserver"
source setup-local-env.sh
./start-server.sh
```

**Kết quả:**
- ippserver sẽ chạy và hiển thị logs
- Printer sẽ có tại: `ipp://localhost:631/ipp/print/test-printer`
- Để dừng server: Nhấn `Ctrl+C`

### Cách 2: Chạy trực tiếp

```bash
cd "/Users/trinhtran/Documents/Source-Code/ippexample/test-ippserver"
source setup-local-env.sh
ippserver -C . -r _print
```

**Giải thích các tham số:**
- `-C .` : Chỉ định config directory (thư mục hiện tại)
- `-r _print` : Resource path cho printers (sẽ tìm trong `print/` subdirectory)

---

## 📄 Bước 3: Test In PDF

### Cách 1: Dùng script test-print.sh (Khuyến nghị)

Mở terminal thứ 3 (giữ server đang chạy) và chạy:

```bash
cd "/Users/trinhtran/Documents/Source-Code/ippexample/test-ippserver"
source setup-local-env.sh
./test-print.sh ../examples/vector.pdf
```

**Kết quả:**
- Script sẽ gửi PDF đến ippserver
- File output sẽ được lưu trong `/tmp/ippserver-output/`

### Cách 2: Dùng ipptool trực tiếp

```bash
cd "/Users/trinhtran/Documents/Source-Code/ippexample/test-ippserver"
source setup-local-env.sh

# Test in PDF
ipptool -f ../examples/vector.pdf \
  ipp://localhost:631/ipp/print/test-printer \
  print-job.test
```

**Giải thích:**
- `-f ../examples/vector.pdf` : File PDF cần in
- `ipp://localhost:631/ipp/print/test-printer` : URI của printer
- `print-job.test` : Test file định nghĩa IPP request

### Cách 3: Dùng macOS CUPS (lp command)

```bash
# Thêm printer vào CUPS (chỉ cần làm 1 lần)
lpadmin -p TestIPPPrinter \
  -E \
  -v ipp://localhost:631/ipp/print/test-printer \
  -m everywhere \
  -L "Test IPP Printer"

# In PDF
lp -d TestIPPPrinter ../examples/vector.pdf

# Xem danh sách jobs
lpq -P TestIPPPrinter
```

---

## ✅ Bước 4: Kiểm tra kết quả

### Xem output files

```bash
# Xem files đã được tạo
ls -la /tmp/ippserver-output/

# Xem nội dung directory
find /tmp/ippserver-output -type f
```

**Giải thích:**
- ippserver sẽ lưu mỗi print job thành một file riêng
- File name thường có format: `job-<job-id>.pdf` hoặc tương tự
- Location được định nghĩa trong `print/test-printer.conf` (DeviceURI)

### Kiểm tra printer status

```bash
# Get printer attributes
ipptool ipp://localhost:631/ipp/print/test-printer \
  get-printer-attributes.test
```

---

## 🔍 Debug và Troubleshooting

### Kiểm tra server có chạy

```bash
# Xem process ippserver
ps aux | grep ippserver | grep -v grep

# Kiểm tra port 631
lsof -i :631
```

### Xem logs

- Logs của ippserver sẽ hiển thị trực tiếp trong terminal nơi bạn chạy `start-server.sh`
- Tìm các dòng có `ERROR`, `WARNING` để debug

### Lỗi thường gặp

**1. "Connection refused"**
- **Nguyên nhân:** ippserver chưa chạy hoặc đã dừng
- **Giải pháp:** Khởi động lại ippserver

**2. "File not found"**
- **Nguyên nhân:** Đường dẫn PDF không đúng
- **Giải pháp:** Dùng absolute path hoặc kiểm tra file tồn tại

**3. "Permission denied"**
- **Nguyên nhân:** Không có quyền ghi vào `/tmp/ippserver-output/`
- **Giải pháp:** 
  ```bash
  mkdir -p /tmp/ippserver-output
  chmod 777 /tmp/ippserver-output
  ```

---

## 📝 Cấu hình Printer

File cấu hình: `test-ippserver/print/test-printer.conf`

**Các tham số quan trọng:**

```conf
# Output location
DeviceURI file:///tmp/ippserver-output

# Output format
OutputFormat application/pdf

# Media sizes
Attr keyword media-ready na_letter_8.5x11in,iso_a4_210x297mm
```

**Thay đổi output location:**
- Sửa `DeviceURI` trong config file
- Ví dụ: `DeviceURI file:///Users/trinhtran/Documents/print-output`

**Thêm command để xử lý (ví dụ: watermark):**
```conf
Command /path/to/your/watermark-script.sh
```

---

## 🎯 Quick Start (Tóm tắt)

**Terminal 1 - Setup:**
```bash
cd "/Users/trinhtran/Documents/Source-Code/ippexample/test-ippserver"
source setup-local-env.sh
```

**Terminal 2 - Start Server:**
```bash
cd "/Users/trinhtran/Documents/Source-Code/ippexample/test-ippserver"
source setup-local-env.sh
./start-server.sh
```

**Terminal 3 - Test Print:**
```bash
cd "/Users/trinhtran/Documents/Source-Code/ippexample/test-ippserver"
source setup-local-env.sh
./test-print.sh ../examples/vector.pdf
```

**Kiểm tra kết quả:**
```bash
ls -la /tmp/ippserver-output/
```

---

## 📚 Tài liệu tham khảo

- `test-ippserver/README.md` - Chi tiết về test setup
- `test-ippserver/TEST-GUIDE.md` - Hướng dẫn test chi tiết
- `man ippserver` - Manual của ippserver
- `man ipptool` - Manual của ipptool

---

## 💡 Tips

1. **Chạy server ở background:**
   ```bash
   ./start-server.sh &
   ```

2. **Tự động setup environment:**
   Thêm vào `~/.zshrc`:
   ```bash
   source ~/Documents/Source-Code/ippexample/test-ippserver/setup-local-env.sh
   ```

3. **Test với nhiều files:**
   ```bash
   for pdf in ../examples/*.pdf; do
     ./test-print.sh "$pdf"
   done
   ```

4. **Monitor output directory:**
   ```bash
   watch -n 1 'ls -lh /tmp/ippserver-output/'
   ```
