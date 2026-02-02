# Các Thư Viện PDF Thay Thế PyMuPDF

## 🎯 Vấn Đề Với PyMuPDF

- ❌ Watermark không hiển thị (có thể do API hoặc cách sử dụng)
- ❌ `insert_text()` chỉ hỗ trợ rotate 0°, 90°, 180°, 270° (không hỗ trợ góc tùy ý như 45°)
- ⚠️ Cần C dependencies (khó build trên một số hệ thống)

---

## 📚 Các Thư Viện Thay Thế

### 1. **pypdf + ReportLab** ⭐⭐⭐⭐⭐ (KHUYẾN NGHỊ)

**Ưu điểm:**
- ✅ **Pure Python** - không cần C/C++ dependencies, dễ build
- ✅ **ReportLab hỗ trợ rotation tốt** - có thể rotate text với bất kỳ góc nào (0°-360°)
- ✅ **Đã có code sẵn** - `watermark-old-pypdf2-reportlab.py`
- ✅ **Ổn định** - được sử dụng rộng rãi
- ✅ **Dễ debug** - code rõ ràng, dễ hiểu

**Nhược điểm:**
- ⚠️ Cần 2 thư viện (pypdf + ReportLab) thay vì 1
- ⚠️ Chậm hơn PyMuPDF một chút (nhưng vẫn đủ nhanh)

**Cài đặt:**
```bash
pip3 install pypdf reportlab
# hoặc
pip3 install --user pypdf reportlab
```

**Migration:**
- Code đã có sẵn: `watermark-old-pypdf2-reportlab.py`
- Chỉ cần đổi tên file hoặc restore từ backup

**Khuyến nghị:** ⭐⭐⭐⭐⭐ **NÊN DÙNG** - Ổn định nhất, dễ build nhất

---

### 2. **pikepdf** ⭐⭐⭐⭐

**GitHub:** https://github.com/pikepdf/pikepdf

**Ưu điểm:**
- ✅ **Rất nhanh** - dùng QPDF (C++ library)
- ✅ **Better PDF support** - hỗ trợ PDF tốt hơn
- ✅ **Modern API** - API hiện đại

**Nhược điểm:**
- ❌ **Cần C++ dependencies** - khó build trên macOS
- ❌ **Không thể tạo watermark** - chỉ đọc/ghi PDF
- ⚠️ Vẫn cần ReportLab để vẽ watermark

**Usage:**
```python
import pikepdf
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from io import BytesIO

# Tạo watermark với ReportLab
watermark_pdf = BytesIO()
c = canvas.Canvas(watermark_pdf, pagesize=letter)
c.saveState()
c.translate(letter[0]/2, letter[1]/2)
c.rotate(45)  # Rotate bất kỳ góc nào!
c.setFont("Helvetica", 50)
c.setFillColorRGB(0.8, 0.8, 0.8)
c.drawString(0, 0, "WATERMARK")
c.restoreState()
c.save()

# Merge với PDF gốc
pdf = pikepdf.Pdf.open('input.pdf')
watermark = pikepdf.Pdf.open(watermark_pdf)
# ... merge logic ...
pdf.save('output.pdf')
```

**Khuyến nghị:** ⭐⭐⭐⭐ Tốt nhưng phức tạp hơn (cần C++)

---

### 3. **pdfrw** ⭐⭐⭐

**GitHub:** https://github.com/pmaupin/pdfrw

**Ưu điểm:**
- ✅ **Lightweight** - nhẹ, đơn giản
- ✅ **Pure Python** - không cần C extensions

**Nhược điểm:**
- ⚠️ **Limited features** - tính năng hạn chế
- ⚠️ **Không thể tạo watermark** - vẫn cần ReportLab
- ⚠️ **Ít được maintain** - ít update

**Khuyến nghị:** ⭐⭐⭐ Không khuyến nghị (limited features)

---

### 4. **pdfplumber** ⭐⭐

**GitHub:** https://github.com/jsvine/pdfplumber

**Ưu điểm:**
- ✅ **Good for text extraction** - tốt cho extract text
- ✅ **Table extraction** - extract tables tốt

**Nhược điểm:**
- ❌ **Không thể watermark** - chỉ đọc PDF
- ❌ **Không thể ghi PDF** - chỉ đọc

**Khuyến nghị:** ⭐⭐ Không phù hợp cho watermarking

---

## 📊 So Sánh Nhanh

| Library | Đọc PDF | Ghi PDF | Vẽ Watermark | Rotation | Dependencies | Khuyến nghị |
|---------|---------|---------|--------------|----------|--------------|-------------|
| **pypdf + ReportLab** | ✅ | ✅ | ✅ | ✅ Bất kỳ góc | Pure Python | ⭐⭐⭐⭐⭐ |
| **pikepdf + ReportLab** | ✅ | ✅ | ✅ | ✅ Bất kỳ góc | C++ library | ⭐⭐⭐⭐ |
| **PyMuPDF** | ✅ | ✅ | ✅ | ⚠️ Chỉ 0/90/180/270 | C library | ⭐⭐⭐ |
| **pdfrw + ReportLab** | ✅ | ✅ | ✅ | ✅ Bất kỳ góc | Pure Python | ⭐⭐⭐ |

---

## 💡 Khuyến Nghị

### **Chuyển về pypdf + ReportLab** ⭐⭐⭐⭐⭐

**Lý do:**
1. ✅ **Pure Python** - dễ build, không cần C dependencies
2. ✅ **ReportLab hỗ trợ rotation tốt** - có thể rotate text với bất kỳ góc nào
3. ✅ **Đã có code sẵn** - `watermark-old-pypdf2-reportlab.py`
4. ✅ **Ổn định** - được sử dụng rộng rãi, ít bug
5. ✅ **Dễ debug** - code rõ ràng, dễ hiểu

**Các bước:**
1. Restore code từ `watermark-old-pypdf2-reportlab.py`
2. Cài đặt: `pip3 install pypdf reportlab`
3. Test lại watermark với rotation

---

## 🔄 Migration Path

### Option 1: Restore từ backup (Nhanh nhất - 5 phút)

```bash
# Restore code cũ
cp watermark-old-pypdf2-reportlab.py watermark.py

# Cài đặt dependencies
pip3 install pypdf reportlab

# Test
python3 test-pdf-simple.py
```

### Option 2: Update build script

```bash
# Update build-all.sh để build pypdf + reportlab thay vì PyMuPDF
# Sau đó chạy
./build-all.sh
```

---

## 📝 Code Example: pypdf + ReportLab

```python
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from io import BytesIO

def create_watermark(text, rotation=45):
    """Tạo watermark PDF với ReportLab"""
    watermark_pdf = BytesIO()
    c = canvas.Canvas(watermark_pdf, pagesize=letter)
    c.saveState()
    
    # Center và rotate
    c.translate(letter[0]/2, letter[1]/2)
    c.rotate(rotation)  # Rotate bất kỳ góc nào!
    
    # Vẽ text
    c.setFont("Helvetica", 100)
    c.setFillColorRGB(1.0, 0.0, 0.0)  # Red
    c.drawString(0, 0, text)
    
    c.restoreState()
    c.save()
    watermark_pdf.seek(0)
    return watermark_pdf

def apply_watermark(input_pdf, output_pdf, watermark_text="WATERMARK", rotation=45):
    """Apply watermark vào PDF"""
    # Tạo watermark
    watermark = create_watermark(watermark_text, rotation)
    watermark_reader = PdfReader(watermark)
    watermark_page = watermark_reader.pages[0]
    
    # Đọc PDF gốc
    reader = PdfReader(input_pdf)
    writer = PdfWriter()
    
    # Merge watermark vào mỗi page
    for page in reader.pages:
        page.merge_page(watermark_page)
        writer.add_page(page)
    
    # Save
    with open(output_pdf, 'wb') as f:
        writer.write(f)
```

---

## ✅ Kết Luận

**Khuyến nghị:** Chuyển về **pypdf + ReportLab**

- ✅ Pure Python, dễ build
- ✅ Hỗ trợ rotation tốt (bất kỳ góc nào)
- ✅ Đã có code sẵn
- ✅ Ổn định, ít bug

**Next Steps:**
1. Restore `watermark-old-pypdf2-reportlab.py` → `watermark.py`
2. Cài đặt `pypdf` và `reportlab`
3. Test lại watermark với rotation
