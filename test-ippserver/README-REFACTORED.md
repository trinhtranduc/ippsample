# IPP Server Scripts - Refactored

## 📋 Tổng Quan

Đã refactor lại toàn bộ scripts thành **4 scripts chính**:

1. **`build-all.sh`** - Build tất cả dependencies (libcups, ipptool, ippserver, Python deps)
2. **`setup-ippserver.sh`** - Tạo và start ippserver
3. **`setup-virtual-printer.sh`** - Tạo virtual printer để test
4. **`reset-all.sh`** - Reset printers và cleanup

---

## 1. Build All Dependencies

### **`build-all.sh`**

**Mục đích:** Build tất cả dependencies cần thiết:
- libcups (CUPS library)
- ipptool, ippserver, ippfind, ippproxy (IPP tools)
- PyMuPDF (Python PDF library)

**Cách sử dụng:**
```bash
# Build tất cả
./build-all.sh

# Build với options
./build-all.sh --skip-python      # Skip Python dependencies
./build-all.sh --skip-cups        # Skip CUPS/IPP tools
./build-all.sh --clean            # Clean trước khi build
```

**Output:**
- IPP tools: `$HOME/local/bin/` (ippserver, ipptool, ippfind, etc.)
- Libraries: `$HOME/local/lib/`
- Python deps: Installed via pip or build script

**Lưu ý:**
- Cần chạy script này **đầu tiên** trước khi dùng các scripts khác
- Build prefix mặc định: `$HOME/local`
- Có thể override: `BUILD_PREFIX=/custom/path ./build-all.sh`

---

## 2. Setup IPP Server

### **`setup-ippserver.sh`**

**Mục đích:** Tạo và start ippserver (IPP server chính)

**Cách sử dụng:**
```bash
# Start ippserver
./setup-ippserver.sh

# Start với custom IP/hostname
./setup-ippserver.sh 192.168.1.100

# Start với custom printer name
./setup-ippserver.sh --printer-name my-printer

# Stop ippserver
./setup-ippserver.sh --stop

# Check status
./setup-ippserver.sh --status

# Disable Bonjour/DNS-SD
./setup-ippserver.sh --no-dns-sd
```

**Configuration:**
- Default port: `8631`
- Default printer name: `ippserver`
- Printer URI: `ipp://HOSTNAME:8631/ipp/print/ippserver`

**Lưu ý:**
- Script tự động detect hostname/IP
- Kiểm tra Python dependencies nếu watermark enabled
- Output files: `$SCRIPT_DIR/print/` (từ ippprinter.conf)

---

## 3. Setup Virtual Printer

### **`setup-virtual-printer.sh`**

**Mục đích:** Tạo virtual printer để test (IPP server ảo)

**Cách sử dụng:**
```bash
# Start virtual printer
./setup-virtual-printer.sh start

# Stop virtual printer
./setup-virtual-printer.sh stop

# Check status
./setup-virtual-printer.sh status

# Restart
./setup-virtual-printer.sh restart
```

**Environment Variables:**
```bash
# Custom port
VIRTUAL_PRINTER_PORT=8640 ./setup-virtual-printer.sh start

# Custom name
VIRTUAL_PRINTER_NAME=test-printer ./setup-virtual-printer.sh start
```

**Output:**
- Printer URI: `ipp://localhost:8632/ipp/print/virtual-printer`
- Output files: `/tmp/virtual-printer-output/`
- Log file: `/tmp/virtual-printer.log`

**Lưu ý:**
- Virtual printer **KHÔNG** tự động add vào CUPS
- Dùng để test hoặc simulate printer
- Port mặc định: `8632` (khác với ippserver chính: `8631`)

---

## 4. Reset All

### **`reset-all.sh`**

**Mục đích:** Reset printers và cleanup

**Cách sử dụng:**
```bash
# Reset tất cả
./reset-all.sh
```

**Chức năng:**
1. Stop tất cả ippserver processes (ports 8631, 8632, 8501)
2. Remove tất cả printers từ CUPS
3. Cleanup temporary files và spool directories

**Lưu ý:**
- Script không cần sudo (trừ khi remove printers yêu cầu)
- An toàn để chạy nhiều lần
- Không xóa configuration files

---

## 🔄 Workflow Điển Hình

### Lần đầu setup:
```bash
# 1. Build dependencies
./build-all.sh

# 2. Start ippserver
./setup-ippserver.sh

# 3. Add printer to CUPS (manual hoặc dùng script khác)
lpadmin -p ippserver -E -v ipp://localhost:8631/ipp/print/ippserver -m everywhere
```

### Test với virtual printer:
```bash
# 1. Start virtual printer
./setup-virtual-printer.sh start

# 2. Test print job
ipptool -vt ipp://localhost:8632/ipp/print/virtual-printer print-job.test

# 3. Check output
ls -la /tmp/virtual-printer-output/
```

### Reset và start lại:
```bash
# 1. Reset tất cả
./reset-all.sh

# 2. Start lại ippserver
./setup-ippserver.sh
```

---

## 📁 Cấu Trúc Files

```
test-ippserver/
├── build-all.sh              # Build tất cả dependencies
├── setup-ippserver.sh        # Setup và start ippserver
├── setup-virtual-printer.sh  # Setup virtual printer
├── reset-all.sh              # Reset printers và cleanup
│
├── print/                    # ippserver configuration
│   └── ippprinter.conf       # Printer config (watermark, etc.)
│
├── watermark.sh              # Watermark script (called by ippserver)
├── watermark.py              # Python watermark script (PyMuPDF)
│
└── unified-logger.sh         # Unified logging utility
```

---

## 🔧 Environment Variables

### Build:
- `BUILD_PREFIX` - Build installation prefix (default: `$HOME/local`)

### IPP Server:
- `PORT` - ippserver port (default: `8631`)
- `PRINTER_NAME` - Printer name (default: `ippserver`)
- `HOSTNAME` - Hostname/IP (auto-detect nếu không set)

### Virtual Printer:
- `VIRTUAL_PRINTER_PORT` - Virtual printer port (default: `8632`)
- `VIRTUAL_PRINTER_NAME` - Virtual printer name (default: `virtual-printer`)

---

## 📝 Lưu Ý

1. **Build trước:** Luôn chạy `build-all.sh` trước khi dùng các scripts khác
2. **Environment:** Scripts tự động source `setup-local-env.sh` nếu có
3. **Ports:** 
   - ippserver chính: `8631`
   - Virtual printer: `8632`
4. **Watermark:** Tự động check Python dependencies nếu watermark enabled
5. **Logging:** Tất cả logs ghi vào unified log file (nếu có unified-logger.sh)

---

## 🆘 Troubleshooting

### ippserver not found:
```bash
# Build dependencies
./build-all.sh

# Setup environment
source setup-local-env.sh
```

### Port already in use:
```bash
# Stop existing ippserver
./setup-ippserver.sh --stop

# Hoặc dùng port khác
PORT=8640 ./setup-ippserver.sh
```

### Python dependencies missing:
```bash
# Build Python deps
./build-all.sh

# Hoặc install manually
pip3 install PyMuPDF
```

---

## 📚 Scripts Cũ (Deprecated)

Các scripts cũ vẫn còn nhưng không khuyến nghị dùng:
- `start-server.sh` → Dùng `setup-ippserver.sh`
- `create-virtual-printer.sh` → Dùng `setup-virtual-printer.sh`
- `reset-printers.sh` → Dùng `reset-all.sh`

Scripts cũ sẽ được giữ lại để backward compatibility nhưng sẽ không được maintain.
