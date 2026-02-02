#!/bin/bash
#
# Watermark script cho ippserver
# Script này sẽ được gọi tự động cho mọi print job (từ lp hoặc ipptool)
#
# Arguments:
#   $1 = Input file (job file từ ippserver spool directory)
#
# Output: Ghi vào DeviceURI (từ environment variable DEVICE_URI)
#
# Lưu ý: 
#   - Khi có Command, ippserver redirect stdout vào /dev/null
#   - Script phải tự ghi vào DeviceURI thay vì stdout
#   - DeviceURI format: file:///path/to/directory hoặc file:///path/to/file
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

# Load unified logging utility (tất cả log ghi vào 1 file)
if [ ! -f "$SCRIPT_DIR/unified-logger.sh" ]; then
    echo "[WATERMARK ERROR] unified-logger.sh not found at $SCRIPT_DIR/unified-logger.sh" >&2
    exit 1
fi
source "$SCRIPT_DIR/unified-logger.sh"
# Override script name để dễ nhận biết trong log
_SCRIPT_NAME="watermark"

# Activate virtual environment nếu có (CÁCH CHUẨN NHẤT trên macOS)
if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
    log_debug "Activating virtual environment: $VENV_DIR"
    source "$VENV_DIR/bin/activate"
    # Override python3 command để dùng venv Python
    if [ -f "$VENV_DIR/bin/python3" ]; then
        # Export để watermark.py có thể dùng
        export VIRTUAL_ENV="$VENV_DIR"
        export PATH="$VENV_DIR/bin:$PATH"
    fi
fi

INPUT_FILE="$1"

# Function để cài đặt Python dependencies
install_python_dependencies() {
    log_info "Installing Python dependencies (pypdf + reportlab)..."
    
    # Check pip3
    if ! command -v pip3 &>/dev/null; then
        log_error "pip3 not found. Cannot install dependencies."
        return 1
    fi
    
    # Install pypdf
    if ! python3 -c "import pypdf" 2>/dev/null; then
        log_info "Installing pypdf..."
        INSTALL_SUCCESS=false
        
        # Method 1: Thử --user flag (an toàn nhất)
        if pip3 install --user --quiet pypdf >/dev/null 2>&1; then
            if python3 -c "import pypdf" 2>/dev/null; then
                INSTALL_SUCCESS=true
            fi
        fi
        
        # Method 2: Nếu --user fail, thử --break-system-packages
        if [ "$INSTALL_SUCCESS" = false ]; then
            log_warning "--user flag failed, trying --break-system-packages..."
            if pip3 install --break-system-packages --quiet pypdf >/dev/null 2>&1; then
                if python3 -c "import pypdf" 2>/dev/null; then
                    INSTALL_SUCCESS=true
                fi
            fi
        fi
        
        # Verify installation
        if [ "$INSTALL_SUCCESS" = true ]; then
            PYPDF_VERSION=$(python3 -c "import pypdf; print(pypdf.__version__)" 2>/dev/null || echo "unknown")
            log_info "pypdf installation completed (version: $PYPDF_VERSION)"
        else
            log_error "Failed to install pypdf"
            log_warning "Try manually: pip3 install pypdf"
            return 1
        fi
    else
        log_debug "pypdf already installed"
    fi
    
    # Install reportlab
    if ! python3 -c "import reportlab" 2>/dev/null; then
        log_info "Installing reportlab..."
        INSTALL_SUCCESS=false
        
        # Method 1: Thử --user flag (an toàn nhất)
        if pip3 install --user --quiet reportlab >/dev/null 2>&1; then
            if python3 -c "import reportlab" 2>/dev/null; then
                INSTALL_SUCCESS=true
            fi
        fi
        
        # Method 2: Nếu --user fail, thử --break-system-packages
        if [ "$INSTALL_SUCCESS" = false ]; then
            log_warning "--user flag failed, trying --break-system-packages..."
            if pip3 install --break-system-packages --quiet reportlab >/dev/null 2>&1; then
                if python3 -c "import reportlab" 2>/dev/null; then
                    INSTALL_SUCCESS=true
                fi
            fi
        fi
        
        # Verify installation
        if [ "$INSTALL_SUCCESS" = true ]; then
            REPORTLAB_VERSION=$(python3 -c "import reportlab; print(reportlab.Version)" 2>/dev/null || echo "unknown")
            log_info "reportlab installation completed (version: $REPORTLAB_VERSION)"
        else
            log_error "Failed to install reportlab"
            log_warning "Try manually: pip3 install reportlab"
            return 1
        fi
    else
        log_debug "reportlab already installed"
    fi
    
    # Verify installation
    if python3 -c "import pypdf, reportlab" 2>/dev/null; then
        PYPDF_VERSION=$(python3 -c "import pypdf; print(pypdf.__version__)" 2>/dev/null || echo "unknown")
        REPORTLAB_VERSION=$(python3 -c "import reportlab; print(reportlab.Version)" 2>/dev/null || echo "unknown")
        log_info "Dependencies installed successfully"
        log_debug "pypdf version: $PYPDF_VERSION, reportlab version: $REPORTLAB_VERSION"
        return 0
    else
        log_error "Installation verification failed"
        return 1
    fi
}

log_debug "Starting watermark script"
log_debug "Input file: $INPUT_FILE"
log_debug "DEVICE_URI: ${DEVICE_URI:-<not set>}"
log_debug "CONTENT_TYPE: ${CONTENT_TYPE:-<not set>}"

# Kiểm tra file tồn tại
if [ ! -f "$INPUT_FILE" ]; then
    log_error "Input file not found: $INPUT_FILE"
    exit 1
fi

# Xác định output file từ DeviceURI
OUTPUT_FILE=""
if [ -n "$DEVICE_URI" ]; then
    # Parse DeviceURI: file:///path/to/directory hoặc file:///path/to/file
    if [[ "$DEVICE_URI" =~ ^file://(.*) ]]; then
        DEVICE_PATH="${BASH_REMATCH[1]}"
        log_debug "Parsed DeviceURI path: $DEVICE_PATH"
        
        # Nếu là directory, tạo output filename dựa trên input filename
        if [ -d "$DEVICE_PATH" ]; then
            # Extract job ID và name từ input filename
            # Format: /path/to/spool/printer_name/job_id-job_name.ext
            INPUT_BASENAME=$(basename "$INPUT_FILE")
            # LUÔN đảm bảo output file có extension .pdf (bỏ extension cũ nếu có)
            # Remove any existing extension and add .pdf
            INPUT_NAME_NO_EXT="${INPUT_BASENAME%.*}"
            OUTPUT_FILE="$DEVICE_PATH/${INPUT_NAME_NO_EXT}.pdf"
            log_debug "DeviceURI is directory, output file: $OUTPUT_FILE"
        elif [ -f "$DEVICE_PATH" ] || [ ! -e "$DEVICE_PATH" ]; then
            # Nếu là file hoặc không tồn tại, dùng trực tiếp
            OUTPUT_FILE="$DEVICE_PATH"
            log_debug "DeviceURI is file or new file, output file: $OUTPUT_FILE"
        else
            log_error "Invalid DeviceURI path: $DEVICE_PATH"
            exit 1
        fi
    else
        log_warning "DeviceURI is not a file:// URI: $DEVICE_URI"
        log_warning "Will write to stdout (may be lost)"
    fi
else
    log_warning "DEVICE_URI not set, will write to stdout (may be lost)"
fi

# Kiểm tra file type
FILE_TYPE=$(file -b --mime-type "$INPUT_FILE" 2>/dev/null || echo "application/octet-stream")
log_debug "Detected file type: $FILE_TYPE"

# Nếu là PDF, watermark bằng Python
if [[ "$FILE_TYPE" == "application/pdf" ]]; then
    log_debug "Processing as PDF file"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Kiểm tra Python và PyPDF2/reportlab
    if command -v python3 &>/dev/null; then
        log_debug "python3 found: $(python3 --version 2>&1)"
        
        # Tìm Python script
        PYTHON_SCRIPT="$SCRIPT_DIR/watermark.py"
        
        # Kiểm tra Python script tồn tại
        if [ ! -f "$PYTHON_SCRIPT" ]; then
            log_error "Python script not found: $PYTHON_SCRIPT"
            # Fallback: copy file nếu không có Python script
            if [ -n "$OUTPUT_FILE" ]; then
                log_warning "Copying original file (Python script not found)"
                cp "$INPUT_FILE" "$OUTPUT_FILE" || exit 1
                exit 0
            fi
        else
            # Check và cài đặt dependencies nếu cần
            if ! python3 -c "import pypdf, reportlab" 2>/dev/null; then
                log_warning "pypdf or reportlab not available"
                log_info "Attempting automatic installation..."
                
                if install_python_dependencies; then
                    # Verify lại sau khi cài
                    if ! python3 -c "import pypdf, reportlab" 2>/dev/null; then
                        log_error "pypdf/reportlab installed but still cannot import. Python path issue?"
                        log_error "Python path: $(python3 -c 'import sys; print(\":\".join(sys.path))' 2>/dev/null || echo 'unknown')"
                        log_warning "Please install manually: pip3 install --break-system-packages pypdf reportlab"
                        log_warning "Or run: $SCRIPT_DIR/build-dependencies.sh (build from source)"
                        log_warning "Or run: $SCRIPT_DIR/setup-venv.sh (virtual environment)"
                        
                        # Fallback: copy file nếu không có dependencies
                        if [ -n "$OUTPUT_FILE" ]; then
                            log_warning "Copying original file (dependencies not available)"
                            cp "$INPUT_FILE" "$OUTPUT_FILE" || exit 1
                            exit 0
                        fi
                        exit 1
                    fi
                    log_info "Dependencies installed and verified, proceeding with watermark"
                else
                    log_error "Failed to install dependencies automatically"
                    log_warning "Please install manually: pip3 install --break-system-packages pypdf reportlab"
                    log_warning "Or run: $SCRIPT_DIR/check-dependencies.sh --auto-install"
                    
                    # Fallback: copy file nếu không có dependencies
                    if [ -n "$OUTPUT_FILE" ]; then
                        log_warning "Copying original file (dependencies not available)"
                        cp "$INPUT_FILE" "$OUTPUT_FILE" || exit 1
                        exit 0
                    fi
                    exit 1
                fi
            else
                log_debug "pypdf and reportlab are available"
            fi
            
            # Verify lại trước khi chạy watermark.py
            if ! python3 -c "import pypdf, reportlab" 2>/dev/null; then
                log_error "pypdf or reportlab not available. Cannot watermark."
                if [ -n "$OUTPUT_FILE" ]; then
                    log_warning "Copying original file without watermark"
                    cp "$INPUT_FILE" "$OUTPUT_FILE" || exit 1
                    exit 0
                fi
                exit 1
            fi
        
        # Chạy Python script để watermark
        if [ -n "$OUTPUT_FILE" ]; then
            log_debug "Writing watermarked PDF to: $OUTPUT_FILE"
            python3 "$PYTHON_SCRIPT" "$INPUT_FILE" "$OUTPUT_FILE" 2>&1 | while IFS= read -r line; do
                # Log các message từ Python script
                if [[ "$line" =~ ^\[WATERMARK ]]; then
                    log_info "$line"
                else
                    log_debug "watermark.py: $line"
                fi
            done
        else
            log_debug "Writing watermarked PDF to stdout"
            python3 "$PYTHON_SCRIPT" "$INPUT_FILE" 2>&1 | while IFS= read -r line; do
                if [[ "$line" =~ ^\[WATERMARK ]]; then
                    log_info "$line"
                else
                    echo "$line"
                fi
            done
        fi

        EXIT_CODE=${PIPESTATUS[0]}
        if [ $EXIT_CODE -eq 0 ]; then
            if [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
                OUTPUT_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "0")
                INPUT_SIZE=$(stat -f%z "$INPUT_FILE" 2>/dev/null || stat -c%s "$INPUT_FILE" 2>/dev/null || echo "0")
                log_info "Watermark completed successfully"
                log_debug "Input size: $INPUT_SIZE bytes, Output size: $OUTPUT_SIZE bytes"
                exit 0
            else
                log_error "Output file not created: $OUTPUT_FILE"
                exit 1
            fi
        else
            log_error "Python script exited with code: $EXIT_CODE"
            exit $EXIT_CODE
        fi
    else
        log_error "python3 not found in PATH"
        # Fallback: copy file nếu không có Python
        if [ -n "$OUTPUT_FILE" ]; then
            log_warning "Copying original file (Python not available)"
            cp "$INPUT_FILE" "$OUTPUT_FILE" || exit 1
            exit 0
        fi
    fi
elif [[ "$FILE_TYPE" == "application/postscript" ]] || [[ "$FILE_TYPE" == "application/x-postscript" ]]; then
    log_debug "Processing as PostScript file"
    log_warning "⚠️  Input file is PostScript (not PDF)"
    log_warning "   macOS CUPS is using 'Generic PostScript Printer' driver instead of 'IPP Everywhere'"
    log_warning "   To receive PDF directly, select 'IPP Everywhere' driver in macOS printer settings"
    log_warning ""
    log_warning "   How to fix:"
    log_warning "   1. Open System Settings > Printers & Scanners"
    log_warning "   2. Select printer 'ippprinter'"
    log_warning "   3. Click 'Options & Supplies'"
    log_warning "   4. In 'Driver' tab, select 'IPP Everywhere'"
    log_warning ""
    
    # Thử convert PostScript → PDF
    CONVERTED=false
    TEMP_PDF="/tmp/$(basename "$INPUT_FILE" .prn)_converted.pdf"
    
    # Method 1: Dùng Ghostscript (nếu có)
    if command -v gs &>/dev/null; then
        GS_VERSION=$(gs --version 2>/dev/null || echo "unknown")
        INPUT_SIZE=$(stat -f%z "$INPUT_FILE" 2>/dev/null || stat -c%s "$INPUT_FILE" 2>/dev/null || echo "0")
        log_info "Found Ghostscript (version: $GS_VERSION), converting PostScript to PDF..."
        log_debug "Input file: $INPUT_FILE (size: $INPUT_SIZE bytes)"
        log_debug "Temporary PDF file: $TEMP_PDF"
        
        if gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile="$TEMP_PDF" "$INPUT_FILE" 2>&1 | while IFS= read -r line; do
            log_debug "Ghostscript: $line"
        done; then
            if [ -f "$TEMP_PDF" ] && [ -s "$TEMP_PDF" ]; then
                OUTPUT_SIZE=$(stat -f%z "$TEMP_PDF" 2>/dev/null || stat -c%s "$TEMP_PDF" 2>/dev/null || echo "0")
                log_info "PostScript converted to PDF using Ghostscript"
                log_debug "Output file: $TEMP_PDF (size: $OUTPUT_SIZE bytes)"
                CONVERTED=true
            else
                log_warning "Ghostscript conversion failed (empty output file)"
                rm -f "$TEMP_PDF" 2>/dev/null || true
            fi
        else
            log_warning "Ghostscript conversion failed (command exited with error)"
            rm -f "$TEMP_PDF" 2>/dev/null || true
        fi
    fi
    
    # Method 2: Dùng pstopdf (macOS built-in, nếu có)
    if [ "$CONVERTED" = false ] && (command -v pstopdf &>/dev/null || [ -f "/usr/bin/pstopdf" ]); then
        PSTOPDF_CMD=$(command -v pstopdf 2>/dev/null || echo "/usr/bin/pstopdf")
        INPUT_SIZE=$(stat -f%z "$INPUT_FILE" 2>/dev/null || stat -c%s "$INPUT_FILE" 2>/dev/null || echo "0")
        log_info "Found pstopdf, converting PostScript to PDF..."
        log_debug "Input file: $INPUT_FILE (size: $INPUT_SIZE bytes)"
        log_debug "Temporary PDF file: $TEMP_PDF"
        
        if $PSTOPDF_CMD "$INPUT_FILE" -o "$TEMP_PDF" 2>&1 | while IFS= read -r line; do
            log_debug "pstopdf: $line"
        done; then
            if [ -f "$TEMP_PDF" ] && [ -s "$TEMP_PDF" ]; then
                OUTPUT_SIZE=$(stat -f%z "$TEMP_PDF" 2>/dev/null || stat -c%s "$TEMP_PDF" 2>/dev/null || echo "0")
                log_info "PostScript converted to PDF using pstopdf"
                log_debug "Output file: $TEMP_PDF (size: $OUTPUT_SIZE bytes)"
                CONVERTED=true
            else
                log_warning "pstopdf conversion failed (empty output file)"
                rm -f "$TEMP_PDF" 2>/dev/null || true
            fi
        else
            log_warning "pstopdf conversion failed (command exited with error)"
            rm -f "$TEMP_PDF" 2>/dev/null || true
        fi
    fi
    
    # Nếu convert thành công, watermark PDF
    if [ "$CONVERTED" = true ] && [ -f "$TEMP_PDF" ]; then
        if [ -n "$OUTPUT_FILE" ]; then
            CONVERTED_SIZE=$(stat -f%z "$TEMP_PDF" 2>/dev/null || stat -c%s "$TEMP_PDF" 2>/dev/null || echo "0")
            log_info "Watermarking converted PDF..."
            log_debug "Input PDF (converted): $TEMP_PDF (size: $CONVERTED_SIZE bytes)"
            log_debug "Output file: $OUTPUT_FILE"
            
            # Check và cài đặt dependencies nếu cần (cho converted PDF)
            if ! python3 -c "import PyPDF2, reportlab" 2>/dev/null; then
                log_warning "PyPDF2 or reportlab not available for watermarking converted PDF"
                if install_python_dependencies; then
                    # Verify lại sau khi cài
                    if ! python3 -c "import PyPDF2, reportlab" 2>/dev/null; then
                        log_error "Dependencies installed but still cannot import. Python path issue?"
                        log_error "Python path: $(python3 -c 'import sys; print(\":\".join(sys.path))' 2>/dev/null || echo 'unknown')"
                        # Fallback: copy converted PDF without watermark
                        log_warning "Copying converted PDF without watermark"
                        cp "$TEMP_PDF" "$OUTPUT_FILE" || exit 1
                        rm -f "$TEMP_PDF" 2>/dev/null || true
                        exit 0
                    fi
                    log_info "Dependencies installed and verified, proceeding with watermark"
                else
                    log_error "Failed to install dependencies"
                    # Fallback: copy converted PDF without watermark
                    log_warning "Copying converted PDF without watermark"
                    cp "$TEMP_PDF" "$OUTPUT_FILE" || exit 1
                    rm -f "$TEMP_PDF" 2>/dev/null || true
                    exit 0
                fi
            fi
            
            # Verify lại trước khi chạy watermark.py
            if ! python3 -c "import pypdf, reportlab" 2>/dev/null; then
                log_error "pypdf or reportlab not available. Cannot watermark."
                log_warning "Copying converted PDF without watermark"
                cp "$TEMP_PDF" "$OUTPUT_FILE" || exit 1
                rm -f "$TEMP_PDF" 2>/dev/null || true
                exit 0
            fi
            
            # Chạy watermark và capture output
            python3 "$SCRIPT_DIR/watermark.py" "$TEMP_PDF" "$OUTPUT_FILE" 2>&1 | while IFS= read -r line; do
                # Log các message từ Python script
                if [[ "$line" =~ ^\[WATERMARK ]]; then
                    log_info "$line"
                else
                    log_debug "watermark.py: $line"
                fi
            done
            
            EXIT_CODE=${PIPESTATUS[0]}
            
            # Cleanup temp file
            rm -f "$TEMP_PDF" 2>/dev/null || true
            
            if [ $EXIT_CODE -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
                FINAL_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "0")
                log_info "Watermark completed successfully on converted PDF"
                log_debug "Final output file: $OUTPUT_FILE (size: $FINAL_SIZE bytes)"
                exit 0
            else
                log_error "Failed to watermark converted PDF (exit code: $EXIT_CODE)"
            fi
        fi
    else
        log_warning "⚠️  Cannot convert PostScript → PDF"
        log_warning "   Install Ghostscript: brew install ghostscript"
        log_warning "   Or select 'IPP Everywhere' driver in macOS to receive PDF directly"
    fi
    
    # Fallback: copy PostScript file (no watermark)
    log_warning "Copying PostScript file without watermark (cannot convert)"
else
    log_debug "File type: $FILE_TYPE (not PDF or PostScript), skipping watermark"
fi

# Fallback: Nếu không phải PDF hoặc không có Python, copy file gốc
if [ -n "$OUTPUT_FILE" ]; then
    log_debug "Copying original file to output (no watermark applied)"
    cp "$INPUT_FILE" "$OUTPUT_FILE"
    if [ $? -eq 0 ]; then
        log_debug "File copied successfully to: $OUTPUT_FILE"
    else
        log_error "Failed to copy file to: $OUTPUT_FILE"
        exit 1
    fi
else
    log_debug "Writing original file to stdout (no watermark applied)"
cat "$INPUT_FILE"
fi

log_debug "Watermark script completed"
