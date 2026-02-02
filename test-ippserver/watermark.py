#!/usr/bin/env python3
#
# Python script để watermark PDF
# Sử dụng pypdf + ReportLab
# - pypdf: Đọc/ghi và merge PDF (successor của PyPDF2)
# - ReportLab: Tạo watermark với rotation tốt (hỗ trợ bất kỳ góc nào)
#

import sys
import os
import io
import subprocess

# Thêm local dependencies path vào sys.path nếu có
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_DIR = os.path.join(SCRIPT_DIR, "venv")
BUILT_DEPS_DIR = os.path.join(SCRIPT_DIR, "python-deps-installed")

# Ưu tiên 1: Sử dụng built dependencies (tương tự libcups build từ source)
if os.path.exists(BUILT_DEPS_DIR):
    python_version = f"{sys.version_info.major}.{sys.version_info.minor}"
    built_site_packages = os.path.join(BUILT_DEPS_DIR, "lib", "python" + python_version, "site-packages")
    
    if not os.path.exists(built_site_packages):
        built_lib = os.path.join(BUILT_DEPS_DIR, "lib")
        if os.path.exists(built_lib):
            for item in os.listdir(built_lib):
                if item.startswith("python"):
                    potential_site_packages = os.path.join(built_lib, item, "site-packages")
                    if os.path.exists(potential_site_packages):
                        built_site_packages = potential_site_packages
                        break
    
    if os.path.exists(built_site_packages):
        sys.path.insert(0, built_site_packages)

# Ưu tiên 2: Sử dụng virtual environment
if os.path.exists(VENV_DIR):
    venv_site_packages = os.path.join(VENV_DIR, "lib", "python" + str(sys.version_info.major) + "." + str(sys.version_info.minor), "site-packages")
    if not os.path.exists(venv_site_packages):
        venv_lib = os.path.join(VENV_DIR, "lib")
        if os.path.exists(venv_lib):
            for item in os.listdir(venv_lib):
                if item.startswith("python"):
                    potential_site_packages = os.path.join(venv_lib, item, "site-packages")
                    if os.path.exists(potential_site_packages):
                        venv_site_packages = potential_site_packages
                        break
    
    if os.path.exists(venv_site_packages):
        sys.path.insert(0, venv_site_packages)

# Import pypdf và reportlab
try:
    from pypdf import PdfReader, PdfWriter
except ImportError:
    print("[WATERMARK ERROR] pypdf not found. Please install dependencies.", file=sys.stderr)
    print(f"[WATERMARK INFO] Run: pip3 install pypdf", file=sys.stderr)
    print(f"[WATERMARK INFO] Or: {os.path.join(SCRIPT_DIR, 'build-all.sh')}", file=sys.stderr)
    sys.exit(1)

try:
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import letter
except ImportError:
    print("[WATERMARK ERROR] reportlab not found. Please install dependencies.", file=sys.stderr)
    print(f"[WATERMARK INFO] Run: pip3 install reportlab", file=sys.stderr)
    print(f"[WATERMARK INFO] Or: {os.path.join(SCRIPT_DIR, 'build-all.sh')}", file=sys.stderr)
    sys.exit(1)

# Unified logging support
def log_to_unified_log(level, message, script_name="watermark"):
    """Ghi log vào unified log file"""
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        logger_py = os.path.join(script_dir, "unified-logger.py")
        
        if os.path.exists(logger_py):
            subprocess.run(
                [sys.executable, logger_py, "--level", level, "--script-name", script_name, message],
                check=False,
                stderr=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL
            )
    except Exception:
        pass

def log_message(level, message):
    """Ghi log vừa vào stderr (console) vừa vào unified log file"""
    print(f"[WATERMARK {level}] {message}", file=sys.stderr)
    log_to_unified_log(level, message, "watermark")


class PDFWatermarker:
    """Class để watermark PDF files sử dụng pypdf + ReportLab"""
    
    def __init__(self, watermark_text="WATERMARK", font_size=100, 
                 color=(1.0, 0.0, 0.0), rotation=45):
        """
        Khởi tạo PDFWatermarker
        
        Args:
            watermark_text: Text để watermark (default: "WATERMARK")
            font_size: Kích thước font (default: 100)
            color: Màu RGB tuple (default: (1.0, 0.0, 0.0) - đỏ)
            rotation: Góc xoay watermark (default: 45 độ) - hỗ trợ bất kỳ góc nào!
        """
        self.watermark_text = watermark_text
        self.font_size = font_size
        self.color = color
        self.rotation = rotation
    
    def create_watermark_pdf(self, page_width, page_height):
        """
        Tạo watermark PDF với ReportLab
        
        Args:
            page_width: Chiều rộng của page
            page_height: Chiều cao của page
            
        Returns:
            BytesIO object chứa watermark PDF
        """
        watermark_pdf = io.BytesIO()
        
        # Tạo canvas với kích thước page
        c = canvas.Canvas(watermark_pdf, pagesize=(page_width, page_height))
        c.saveState()
        
        # Di chuyển đến center và rotate
        c.translate(page_width / 2, page_height / 2)
        c.rotate(self.rotation)  # Rotate bất kỳ góc nào!
        
        # Vẽ text watermark
        c.setFont("Helvetica-Bold", self.font_size)
        c.setFillColorRGB(self.color[0], self.color[1], self.color[2])
        
        # Tính toán text width để center
        text_width = c.stringWidth(self.watermark_text, "Helvetica-Bold", self.font_size)
        c.drawString(-text_width / 2, 0, self.watermark_text)
        
        c.restoreState()
        c.save()
        watermark_pdf.seek(0)
        
        return watermark_pdf
    
    def apply_watermark(self, input_file, output_file=None):
        """
        Apply watermark vào PDF file sử dụng pypdf + ReportLab
        
        Args:
            input_file: Đường dẫn đến input PDF file
            output_file: Đường dẫn đến output PDF file (None nếu ghi ra stdout)
            
        Returns:
            True nếu thành công, False nếu có lỗi
        """
        try:
            input_size = os.path.getsize(input_file)
            log_message("INFO", f"Reading PDF file: {input_file} (size: {input_size} bytes)")
            
            # Đọc PDF gốc
            reader = PdfReader(input_file)
            num_pages = len(reader.pages)
            log_message("INFO", f"PDF has {num_pages} page(s)")
            
            log_message("INFO", f"Creating watermark: '{self.watermark_text}' (font: {self.font_size}pt, rotation: {self.rotation}°)")
            
            # Tạo writer
            writer = PdfWriter()
            
            # Process từng page
            for page_num in range(num_pages):
                page = reader.pages[page_num]
                
                # Lấy kích thước page
                page_rect = page.mediabox
                page_width = float(page_rect.width)
                page_height = float(page_rect.height)
                
                log_message("DEBUG", f"Page {page_num + 1}: size {page_width:.1f} x {page_height:.1f}")
                
                # Tạo watermark PDF cho page này
                watermark_pdf = self.create_watermark_pdf(page_width, page_height)
                watermark_reader = PdfReader(watermark_pdf)
                watermark_page = watermark_reader.pages[0]
                
                # Merge watermark vào page (over=False để watermark ở background)
                page.merge_page(watermark_page, over=False)
                
                # Thêm page vào writer
                writer.add_page(page)
                
                if (page_num + 1) % 10 == 0 or (page_num + 1) == num_pages:
                    log_message("INFO", f"Processed {page_num + 1}/{num_pages} page(s)")
            
            # Save PDF
            if output_file:
                log_message("INFO", f"Writing watermarked PDF to: {output_file}")
                temp_output = output_file + ".tmp"
                
                with open(temp_output, 'wb') as f:
                    writer.write(f)
                
                # Atomic move
                os.replace(temp_output, output_file)
                
                if os.path.exists(output_file):
                    output_size = os.path.getsize(output_file)
                    log_message("INFO", f"Watermark completed successfully")
                    log_message("DEBUG", f"Input size: {input_size} bytes, Output size: {output_size} bytes")
                    
                    # Verify PDF
                    verify_reader = PdfReader(output_file)
                    verify_pages = len(verify_reader.pages)
                    verify_reader.stream.close()
                    
                    if verify_pages == num_pages:
                        log_message("INFO", f"PDF verified: {verify_pages} page(s)")
                        return True
                    else:
                        log_message("WARNING", f"PDF verification failed: expected {num_pages} pages, got {verify_pages}")
                        return False
                else:
                    log_message("ERROR", f"Output file not created: {output_file}")
                    return False
            else:
                log_message("INFO", "Writing watermarked PDF to stdout")
                writer.write(sys.stdout.buffer)
                return True
                
        except Exception as e:
            log_message("ERROR", f"Failed to watermark PDF: {str(e)}")
            import traceback
            log_message("DEBUG", traceback.format_exc())
            return False


def main():
    """Main function để chạy từ command line"""
    import argparse
    
    # Named colors mapping
    NAMED_COLORS = {
        'red': (1.0, 0.0, 0.0),
        'green': (0.0, 1.0, 0.0),
        'blue': (0.0, 0.0, 1.0),
        'yellow': (1.0, 1.0, 0.0),
        'cyan': (0.0, 1.0, 1.0),
        'magenta': (1.0, 0.0, 1.0),
        'black': (0.0, 0.0, 0.0),
        'white': (1.0, 1.0, 1.0),
        'gray': (0.5, 0.5, 0.5),
        'grey': (0.5, 0.5, 0.5),
        'lightgray': (0.8, 0.8, 0.8),
        'lightgrey': (0.8, 0.8, 0.8),
        'darkgray': (0.3, 0.3, 0.3),
        'darkgrey': (0.3, 0.3, 0.3),
    }
    
    def parse_color(value):
        """Parse color value - có thể là named color hoặc RGB values"""
        # Check if it's a named color
        if value.lower() in NAMED_COLORS:
            return NAMED_COLORS[value.lower()]
        
        # Try to parse as RGB values (comma or space separated)
        try:
            # Try comma-separated: "1.0,0.0,0.0"
            if ',' in value:
                parts = [float(x.strip()) for x in value.split(',')]
            # Try space-separated: "1.0 0.0 0.0"
            else:
                parts = [float(x) for x in value.split()]
            
            if len(parts) != 3:
                raise ValueError("Color must have 3 values (R, G, B)")
            
            # Validate range (0.0 - 1.0)
            for i, v in enumerate(parts):
                if v < 0.0 or v > 1.0:
                    raise ValueError(f"Color value {v} out of range [0.0, 1.0]")
            
            return tuple(parts)
        except (ValueError, AttributeError) as e:
            raise argparse.ArgumentTypeError(f"Invalid color: {value}. Use named color (red, blue, etc.) or RGB values (0.0-1.0)")
    
    parser = argparse.ArgumentParser(
        description="Watermark PDF files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage with default red color
  %(prog)s input.pdf -o output.pdf -t "WATERMARK" -r 45
  
  # With RGB color values
  %(prog)s input.pdf -o output.pdf -t "WATERMARK" -r 45 -c 0.0 0.0 1.0
  
  # With named color
  %(prog)s input.pdf -o output.pdf -t "WATERMARK" -r 45 -c blue
  
  # With comma-separated RGB
  %(prog)s input.pdf -o output.pdf -t "WATERMARK" -r 45 -c "0.5,0.5,0.5"

Named colors: red, green, blue, yellow, cyan, magenta, black, white, gray, lightgray, darkgray
        """
    )
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("-o", "--output", help="Output PDF file (default: stdout)")
    parser.add_argument("-t", "--text", default="WATERMARK", help="Watermark text (default: WATERMARK)")
    parser.add_argument("-s", "--size", type=int, default=100, help="Font size (default: 100)")
    parser.add_argument("-r", "--rotation", type=float, default=45, help="Rotation angle in degrees (default: 45)")
    parser.add_argument("-c", "--color", type=parse_color, default=(1.0, 0.0, 0.0), 
                        help="Watermark color. Can be a named color (red, blue, etc.) or RGB values (0.0-1.0). "
                             "For RGB, use space or comma separated: '1.0 0.0 0.0' or '1.0,0.0,0.0' (default: red)")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input):
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)
    
    watermarker = PDFWatermarker(
        watermark_text=args.text,
        font_size=args.size,
        color=args.color,
        rotation=args.rotation
    )
    
    success = watermarker.apply_watermark(args.input, args.output)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
