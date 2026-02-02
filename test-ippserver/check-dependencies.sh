#!/bin/bash
#
# Script để kiểm tra và cài đặt Python dependencies cho watermark
#

echo "🔍 Kiểm tra Python Dependencies"
echo "================================"
echo ""

MISSING_DEPS=0

# Kiểm tra Python
if ! command -v python3 &>/dev/null; then
    echo "❌ python3 không có trong PATH"
    echo ""
    echo "Cài đặt Python:"
    echo "  brew install python3"
    exit 1
fi

echo "✅ python3 found: $(which python3)"
echo "   Version: $(python3 --version)"
echo ""

# Kiểm tra pip3
if ! command -v pip3 &>/dev/null; then
    echo "❌ pip3 không có trong PATH"
    echo ""
    echo "Cài đặt pip3:"
    echo "  python3 -m ensurepip --upgrade"
    exit 1
fi

echo "✅ pip3 found: $(which pip3)"
echo ""

# Kiểm tra pypdf
echo "📦 Kiểm tra pypdf..."
if python3 -c "import pypdf" 2>/dev/null; then
    PYPDF_VERSION=$(python3 -c "import pypdf; print(pypdf.__version__)" 2>/dev/null || echo "installed")
    echo "   ✅ pypdf installed (version: $PYPDF_VERSION)"
else
    echo "   ❌ pypdf NOT installed"
    MISSING_DEPS=1
fi

# Kiểm tra reportlab
echo "📦 Kiểm tra reportlab..."
if python3 -c "import reportlab" 2>/dev/null; then
    REPORTLAB_VERSION=$(python3 -c "import reportlab; print(reportlab.Version)" 2>/dev/null || echo "installed")
    echo "   ✅ reportlab installed (version: $REPORTLAB_VERSION)"
else
    echo "   ❌ reportlab NOT installed"
    MISSING_DEPS=1
fi

echo ""

# Nếu thiếu dependencies, hỏi có muốn cài không
if [ $MISSING_DEPS -eq 1 ]; then
    echo "⚠️  Thiếu Python dependencies"
    echo ""
    
    # Nếu có flag --auto-install, cài tự động không hỏi
    if [ "$1" = "--auto-install" ]; then
        AUTO_INSTALL=true
        echo "   Auto-install mode: Installing dependencies automatically..."
    else
        # Chỉ hỏi nếu có terminal interactive
        if [ -t 0 ]; then
            read -p "Bạn có muốn cài đặt tự động không? (y/N): " -n 1 -r
            echo ""
            AUTO_INSTALL=false
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                AUTO_INSTALL=true
            fi
        else
            # Non-interactive mode, không cài tự động
            AUTO_INSTALL=false
            echo "   Non-interactive mode. Run with --auto-install to install automatically."
        fi
    fi
    
    if [ "$AUTO_INSTALL" = true ]; then
        echo "📥 Đang cài đặt dependencies..."
        echo ""
        
        # Cài pypdf
        if ! python3 -c "import pypdf" 2>/dev/null; then
            echo "   Installing pypdf..."
            INSTALL_SUCCESS=false
            
            # Method 1: Thử --user flag (an toàn nhất)
            # Suppress cả stdout và stderr để không hiển thị error messages
            if pip3 install --user --quiet pypdf >/dev/null 2>&1; then
                if python3 -c "import pypdf" 2>/dev/null; then
                    INSTALL_SUCCESS=true
                fi
            fi
            
            # Method 2: Nếu --user fail, thử --break-system-packages
            if [ "$INSTALL_SUCCESS" = false ]; then
                echo "   ⚠️  --user flag failed, trying --break-system-packages..."
                # Suppress cả stdout và stderr
                if pip3 install --break-system-packages --quiet pypdf >/dev/null 2>&1; then
                    if python3 -c "import pypdf" 2>/dev/null; then
                        INSTALL_SUCCESS=true
                        echo "   ⚠️  Installed with --break-system-packages (not recommended)"
                    fi
                fi
            fi
            
            # Verify installation
            if [ "$INSTALL_SUCCESS" = true ]; then
                PYPDF_VERSION=$(python3 -c "import pypdf; print(pypdf.__version__)" 2>/dev/null || echo "unknown")
                echo "   ✅ pypdf installed (version: $PYPDF_VERSION)"
            else
                echo "   ❌ Failed to install pypdf"
                echo "   Please install manually:"
                echo "     pip3 install --user pypdf"
                echo "     Or: pip3 install --break-system-packages pypdf"
                exit 1
            fi
        fi
        
        # Cài reportlab
        if ! python3 -c "import reportlab" 2>/dev/null; then
            echo "   Installing reportlab..."
            INSTALL_SUCCESS=false
            
            # Method 1: Thử --user flag (an toàn nhất)
            # Suppress cả stdout và stderr để không hiển thị error messages
            if pip3 install --user --quiet reportlab >/dev/null 2>&1; then
                if python3 -c "import reportlab" 2>/dev/null; then
                    INSTALL_SUCCESS=true
                fi
            fi
            
            # Method 2: Nếu --user fail, thử --break-system-packages
            if [ "$INSTALL_SUCCESS" = false ]; then
                echo "   ⚠️  --user flag failed, trying --break-system-packages..."
                # Suppress cả stdout và stderr
                if pip3 install --break-system-packages --quiet reportlab >/dev/null 2>&1; then
                    if python3 -c "import reportlab" 2>/dev/null; then
                        INSTALL_SUCCESS=true
                        echo "   ⚠️  Installed with --break-system-packages (not recommended)"
                    fi
                fi
            fi
            
            # Verify installation
            if [ "$INSTALL_SUCCESS" = true ]; then
                REPORTLAB_VERSION=$(python3 -c "import reportlab; print(reportlab.Version)" 2>/dev/null || echo "unknown")
                echo "   ✅ reportlab installed (version: $REPORTLAB_VERSION)"
            else
                echo "   ❌ Failed to install reportlab"
                echo "   Please install manually:"
                echo "     pip3 install --user reportlab"
                echo "     Or: pip3 install --break-system-packages reportlab"
                exit 1
            fi
        fi
        
        echo ""
        echo "✅ Tất cả dependencies đã được cài đặt!"
        echo ""
        
        # Verify lại
        echo "🔍 Verifying..."
        if python3 -c "import pypdf, reportlab" 2>/dev/null; then
            echo "✅ All dependencies OK!"
            exit 0
        else
            echo "❌ Verification failed"
            exit 1
        fi
    else
        echo "⚠️  Dependencies chưa được cài đặt"
        echo ""
        echo "Cài đặt thủ công:"
        echo "  pip3 install pypdf reportlab"
        exit 1
    fi
else
    echo "✅ Tất cả dependencies đã được cài đặt!"
    exit 0
fi
