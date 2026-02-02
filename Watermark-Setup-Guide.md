# Hướng dẫn Watermark Print Jobs từ macOS

## 🎯 Mục tiêu

Watermark tất cả print jobs từ macOS thông qua IPP proxy/server.

## ✅ Hướng đi của bạn là ĐÚNG!

Có **2 cách chính** để watermark print jobs từ macOS:

### Cách 1: Dùng `ippserver` với Print Command (Khuyến nghị)

**Kiến trúc:**
```
macOS App → CUPS mặc định → ippserver (watermark) → Printer thật
```

**Ưu điểm:**
- ✅ Dễ setup và quản lý
- ✅ Có thể customize watermark logic
- ✅ Không cần modify CUPS system
- ✅ Hoạt động với mọi ứng dụng macOS

**Cách hoạt động:**
1. Setup `ippserver` như một IPP printer
2. Cấu hình macOS CUPS để route print jobs qua `ippserver`
3. `ippserver` nhận job, chạy command để watermark
4. Command watermark document và output ra printer thật

### Cách 2: Dùng CUPS Filter (Phức tạp hơn)

**Kiến trúc:**
```
macOS App → CUPS Filter (watermark) → Printer
```

**Ưu điểm:**
- ✅ Tích hợp sâu vào CUPS
- ✅ Tự động cho mọi printer

**Nhược điểm:**
- ❌ Cần modify CUPS system files
- ❌ Phức tạp hơn để maintain
- ❌ Có thể bị overwrite khi update macOS

## 📋 Setup Cách 1: ippserver với Watermark Command

### Bước 1: Tạo Watermark Script

Tạo script để watermark PDF/document:

```bash
#!/bin/bash
# watermark.sh - Watermark script cho ippserver

INPUT_FILE="$1"
OUTPUT_FILE="${INPUT_FILE}.watermarked"

# Ví dụ: Dùng ImageMagick hoặc pdftk để watermark
# Nếu là PDF:
if file "$INPUT_FILE" | grep -q "PDF"; then
    # Dùng pdftk hoặc qpdf
    pdftk "$INPUT_FILE" stamp watermark.pdf output "$OUTPUT_FILE"
    # Hoặc dùng ImageMagick convert
    # convert "$INPUT_FILE" -draw "text 100,100 'WATERMARK'" "$OUTPUT_FILE"
else
    # Copy file nếu không phải PDF (hoặc xử lý format khác)
    cp "$INPUT_FILE" "$OUTPUT_FILE"
fi

# Output file đã watermark
cat "$OUTPUT_FILE"
rm -f "$OUTPUT_FILE"
```

Hoặc dùng Python script:

```python
#!/usr/bin/env python3
# watermark.py - Watermark script

import sys
from PyPDF2 import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
import io

input_file = sys.argv[1]

# Đọc PDF
reader = PdfReader(input_file)
writer = PdfWriter()

# Thêm watermark vào mỗi page
for page in reader.pages:
    # Tạo watermark
    packet = io.BytesIO()
    can = canvas.Canvas(packet, pagesize=letter)
    can.setFont("Helvetica-Bold", 50)
    can.setFillColorRGB(0.8, 0.8, 0.8)  # Màu xám
    can.rotate(45)
    can.drawString(200, 100, "WATERMARK")
    can.save()
    
    # Merge watermark với page
    packet.seek(0)
    watermark = PdfReader(packet)
    watermark_page = watermark.pages[0]
    page.merge_page(watermark_page)
    writer.add_page(page)

# Output ra stdout
output = io.BytesIO()
writer.write(output)
sys.stdout.buffer.write(output.getvalue())
```

### Bước 2: Setup ippserver

**2.1. Tạo config directory:**

```bash
mkdir -p ~/ippserver-config/print
```

**2.2. Tạo printer config (`~/ippserver-config/print/watermark-printer.conf`):**

```conf
# Watermark Printer Configuration
MAKE "Watermark"
MODEL "Watermark Printer"

# Device URI của printer thật (thay bằng printer của bạn)
DeviceURI ipp://printer.local/ipp/print

# Command để watermark (script bạn tạo ở bước 1)
Command /path/to/watermark.sh

# Output format
OutputFormat application/pdf

# Printer attributes
Attr keyword media-ready na_letter_8.5x11in,iso_a4_210x297mm
Attr integer pages-per-minute 10
```

**2.3. Chạy ippserver:**

```bash
# Setup environment
source ~/Documents/Source\ Code/ippexample/setup-local-env.sh

# Chạy ippserver
ippserver -C ~/ippserver-config -r _print
```

ippserver sẽ chạy và expose printer tại:
- `ipp://localhost:631/ipp/print/watermark-printer` (HTTP)
- `ipps://localhost:631/ipp/print/watermark-printer` (HTTPS)

### Bước 3: Cấu hình macOS CUPS

**3.1. Thêm printer qua CUPS web interface:**

```bash
# Mở browser và vào:
open http://localhost:631/admin
```

Hoặc dùng command line:

```bash
# Thêm printer
lpadmin -p WatermarkPrinter \
  -E \
  -v ipp://localhost:631/ipp/print/watermark-printer \
  -m everywhere \
  -L "Watermark Printer"
```

**3.2. Set làm default printer (tùy chọn):**

```bash
lpoptions -d WatermarkPrinter
```

### Bước 4: Test

```bash
# Test print
echo "Test document" | lp -d WatermarkPrinter

# Hoặc print file
lp -d WatermarkPrinter document.pdf
```

## 🔧 Cách 2: Dùng CUPS Filter (Advanced)

Nếu bạn muốn watermark tự động cho mọi printer:

### Bước 1: Tạo CUPS Filter

```bash
# Tạo filter directory
sudo mkdir -p /usr/libexec/cups/filter

# Tạo watermark filter
sudo nano /usr/libexec/cups/filter/watermark
```

Filter script:

```bash
#!/bin/bash
# CUPS Filter để watermark

# CUPS filter nhận input từ stdin và output ra stdout
INPUT="/tmp/cups_watermark_$$.pdf"
OUTPUT="/tmp/cups_watermark_out_$$.pdf"

# Đọc input
cat > "$INPUT"

# Watermark
pdftk "$INPUT" stamp /path/to/watermark.pdf output "$OUTPUT"

# Output
cat "$OUTPUT"

# Cleanup
rm -f "$INPUT" "$OUTPUT"
exit 0
```

```bash
sudo chmod +x /usr/libexec/cups/filter/watermark
```

### Bước 2: Cấu hình Printer để dùng Filter

Edit `/etc/cups/ppd/printer.ppd` và thêm filter.

**Lưu ý:** Cách này phức tạp và có thể bị macOS overwrite khi update.

## 🎨 Watermark Tools

### 1. ImageMagick (cho images)
```bash
brew install imagemagick
convert input.pdf -draw "text 100,100 'WATERMARK'" output.pdf
```

### 2. pdftk (cho PDF)
```bash
brew install pdftk-java
pdftk input.pdf stamp watermark.pdf output output.pdf
```

### 3. Python với PyPDF2/reportlab
```bash
pip install PyPDF2 reportlab
# Xem script ở trên
```

### 4. qpdf (cho PDF manipulation)
```bash
brew install qpdf
qpdf input.pdf --overlay watermark.pdf -- output.pdf
```

## 📝 Lưu ý quan trọng

1. **Performance**: Watermark có thể làm chậm print job
2. **Format support**: Cần xử lý nhiều format (PDF, PostScript, PCL, etc.)
3. **Error handling**: Script cần handle errors gracefully
4. **Logging**: Log để debug khi có vấn đề
5. **Security**: Đảm bảo script không có security holes

## 🔍 Debug

### Kiểm tra ippserver logs:
```bash
# ippserver log ra stderr, có thể redirect
ippserver -C ~/ippserver-config -r _print 2>&1 | tee ippserver.log
```

### Kiểm tra CUPS logs:
```bash
# macOS CUPS logs thường ở:
tail -f /var/log/cups/error_log
```

### Test watermark script trực tiếp:
```bash
./watermark.sh input.pdf > output.pdf
```

## 🚀 Next Steps

1. ✅ Tạo watermark script phù hợp với nhu cầu
2. ✅ Setup ippserver với config
3. ✅ Cấu hình macOS CUPS để route qua ippserver
4. ✅ Test với các loại document khác nhau
5. ✅ Optimize performance nếu cần

## 📚 Tài liệu tham khảo

- `ippserver` man page: `man ippserver`
- IPP Sample Code README: `README.md`
- CUPS Filter documentation: `man cupsfilter`
