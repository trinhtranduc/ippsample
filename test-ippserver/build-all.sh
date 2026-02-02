#!/bin/bash
#
# Script chính để build tất cả dependencies cần thiết:
# - libcups (CUPS library)
# - ipptool, ippserver, ippfind, ippproxy (IPP tools)
# - pypdf + reportlab (Python PDF libraries)
#
# Usage:
#   ./build-all.sh                    # Build tất cả
#   ./build-all.sh --skip-python      # Skip Python dependencies
#   ./build-all.sh --skip-cups        # Skip CUPS/IPP tools
#   ./build-all.sh --clean            # Clean trước khi build
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_PREFIX="${BUILD_PREFIX:-$HOME/local}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Parse arguments
SKIP_PYTHON=false
SKIP_CUPS=false
CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-python)
            SKIP_PYTHON=true
            shift
            ;;
        --skip-cups)
            SKIP_CUPS=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-python    Skip building Python dependencies"
            echo "  --skip-cups      Skip building CUPS/IPP tools"
            echo "  --clean          Clean before building"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_step "Build All Dependencies"
log_info "Build prefix: $BUILD_PREFIX"
log_info "Project root: $PROJECT_ROOT"
echo ""

# Step 1: Build libcups and IPP tools
if [ "$SKIP_CUPS" = false ]; then
    log_step "Step 1: Building libcups and IPP Tools"
    
    cd "$PROJECT_ROOT"
    
    # Clean if requested
    if [ "$CLEAN_BUILD" = true ]; then
        log_info "Cleaning previous build..."
        make clean 2>/dev/null || true
        make distclean 2>/dev/null || true
        rm -rf Makedefs config.h config.log config.status autom4te*.cache 2>/dev/null || true
        
        # Clean libcups
        if [ -d "libcups" ]; then
            cd libcups
            make distclean 2>/dev/null || true
            cd ..
        fi
    fi
    
    # Check if already built - nếu đã có thì bỏ qua
    # ippserver thường ở sbin/, ipptool ở bin/
    IPPSERVER_PATH=""
    IPPTOOL_PATH=""
    
    if [ -f "$BUILD_PREFIX/sbin/ippserver" ]; then
        IPPSERVER_PATH="$BUILD_PREFIX/sbin/ippserver"
    elif [ -f "$BUILD_PREFIX/bin/ippserver" ]; then
        IPPSERVER_PATH="$BUILD_PREFIX/bin/ippserver"
    fi
    
    if [ -f "$BUILD_PREFIX/bin/ipptool" ]; then
        IPPTOOL_PATH="$BUILD_PREFIX/bin/ipptool"
    elif [ -f "$BUILD_PREFIX/sbin/ipptool" ]; then
        IPPTOOL_PATH="$BUILD_PREFIX/sbin/ipptool"
    fi
    
    if [ -n "$IPPSERVER_PATH" ] && [ -n "$IPPTOOL_PATH" ]; then
        log_success "IPP tools already exist:"
        log_info "  ippserver: $IPPSERVER_PATH"
        log_info "  ipptool: $IPPTOOL_PATH"
        log_info "Skipping CUPS/IPP tools build (already built)"
        SKIP_CUPS=true
    fi
    
    if [ "$SKIP_CUPS" = false ]; then
        log_info "Configuring build..."
        
        # Set architecture (ARM64 for Apple Silicon)
        export CFLAGS="-arch arm64"
        export LDFLAGS="-arch arm64"
        
        # Configure
        if [ ! -f "config.status" ] || [ "$CLEAN_BUILD" = true ]; then
            log_info "Running configure..."
            ./configure --disable-shared --prefix="$BUILD_PREFIX" 2>&1 | grep -v "^checking" || true
        else
            log_info "Using existing configuration"
        fi
        
        # Build
        log_info "Building..."
        if ! make -j$(sysctl -n hw.ncpu); then
            log_error "Build failed. Showing last 20 lines of output:"
            make -j$(sysctl -n hw.ncpu) 2>&1 | tail -20
            exit 1
        fi
        
        # Install
        log_info "Installing to $BUILD_PREFIX..."
        # Tạo directories nếu chưa có
        mkdir -p "$BUILD_PREFIX/bin" "$BUILD_PREFIX/lib" "$BUILD_PREFIX/include" "$BUILD_PREFIX/share"
        
        if ! make install prefix="$BUILD_PREFIX"; then
            log_error "Install failed. Showing last 20 lines of output:"
            make install prefix="$BUILD_PREFIX" 2>&1 | tail -20
            exit 1
        fi
        
        # Verify installation - check cả bin/ và sbin/
        IPPSERVER_INSTALLED=""
        IPPTOOL_INSTALLED=""
        IPPFIND_INSTALLED=""
        
        if [ -f "$BUILD_PREFIX/sbin/ippserver" ]; then
            IPPSERVER_INSTALLED="$BUILD_PREFIX/sbin/ippserver"
        elif [ -f "$BUILD_PREFIX/bin/ippserver" ]; then
            IPPSERVER_INSTALLED="$BUILD_PREFIX/bin/ippserver"
        fi
        
        if [ -f "$BUILD_PREFIX/bin/ipptool" ]; then
            IPPTOOL_INSTALLED="$BUILD_PREFIX/bin/ipptool"
        elif [ -f "$BUILD_PREFIX/sbin/ipptool" ]; then
            IPPTOOL_INSTALLED="$BUILD_PREFIX/sbin/ipptool"
        fi
        
        if [ -f "$BUILD_PREFIX/bin/ippfind" ]; then
            IPPFIND_INSTALLED="$BUILD_PREFIX/bin/ippfind"
        elif [ -f "$BUILD_PREFIX/sbin/ippfind" ]; then
            IPPFIND_INSTALLED="$BUILD_PREFIX/sbin/ippfind"
        fi
        
        if [ -n "$IPPSERVER_INSTALLED" ] && [ -n "$IPPTOOL_INSTALLED" ]; then
            log_success "IPP tools installed successfully"
            log_info "  ippserver: $IPPSERVER_INSTALLED"
            log_info "  ipptool: $IPPTOOL_INSTALLED"
            if [ -n "$IPPFIND_INSTALLED" ]; then
                log_info "  ippfind: $IPPFIND_INSTALLED"
            fi
        else
            log_error "IPP tools installation failed"
            log_info "Checking installation directories..."
            log_info "  bin/: $(ls -1 "$BUILD_PREFIX/bin/" 2>/dev/null | head -5 | tr '\n' ' ' || echo 'empty or not found')"
            log_info "  sbin/: $(ls -1 "$BUILD_PREFIX/sbin/" 2>/dev/null | head -5 | tr '\n' ' ' || echo 'empty or not found')"
            exit 1
        fi
    fi
else
    log_info "Skipping CUPS/IPP tools build (--skip-cups)"
fi

# Step 2: Build Python dependencies
if [ "$SKIP_PYTHON" = false ]; then
    log_step "Step 2: Building Python Dependencies (pypdf + reportlab)"
    
    # Check if already installed - nếu đã có thì bỏ qua
    PYPDF_INSTALLED=false
    REPORTLAB_INSTALLED=false
    
    if python3 -c "import pypdf" 2>/dev/null; then
        PYPDF_VERSION=$(python3 -c "import pypdf; print(pypdf.__version__)" 2>/dev/null || echo "installed")
        log_success "pypdf already installed (version: $PYPDF_VERSION)"
        PYPDF_INSTALLED=true
    fi
    
    if python3 -c "import reportlab" 2>/dev/null; then
        REPORTLAB_VERSION=$(python3 -c "import reportlab; print(reportlab.Version)" 2>/dev/null || echo "installed")
        log_success "reportlab already installed (version: $REPORTLAB_VERSION)"
        REPORTLAB_INSTALLED=true
    fi
    
    if [ "$PYPDF_INSTALLED" = true ] && [ "$REPORTLAB_INSTALLED" = true ]; then
        log_info "Skipping Python dependencies build (already installed)"
    else
        cd "$SCRIPT_DIR"
        
        # Install via pip
        if command -v pip3 &>/dev/null; then
            # Install pypdf
            if [ "$PYPDF_INSTALLED" = false ]; then
                log_info "Installing pypdf via pip..."
                
                # Try --user first (an toàn nhất)
                log_info "Trying pip3 install --user pypdf..."
                if pip3 install --user pypdf 2>&1 | tee /tmp/pypdf-install.log; then
                    if python3 -c "import pypdf" 2>/dev/null; then
                        PYPDF_VERSION=$(python3 -c "import pypdf; print(pypdf.__version__)" 2>/dev/null || echo "installed")
                        log_success "pypdf installed successfully (--user, version: $PYPDF_VERSION)"
                    else
                        log_warning "--user install completed but cannot import, trying --break-system-packages..."
                        if pip3 install --break-system-packages pypdf 2>&1 | tee /tmp/pypdf-install.log; then
                            if python3 -c "import pypdf" 2>/dev/null; then
                                PYPDF_VERSION=$(python3 -c "import pypdf; print(pypdf.__version__)" 2>/dev/null || echo "installed")
                                log_success "pypdf installed successfully (--break-system-packages, version: $PYPDF_VERSION)"
                            else
                                log_error "pypdf installation failed - cannot import after install"
                                log_info "Check log: /tmp/pypdf-install.log"
                                exit 1
                            fi
                        else
                            log_error "pypdf installation failed"
                            log_info "Check log: /tmp/pypdf-install.log"
                            exit 1
                        fi
                    fi
                else
                    # --user failed, try --break-system-packages
                    log_warning "--user install failed (externally-managed-environment), trying --break-system-packages..."
                    if pip3 install --break-system-packages pypdf 2>&1 | tee /tmp/pypdf-install.log; then
                        if python3 -c "import pypdf" 2>/dev/null; then
                            PYPDF_VERSION=$(python3 -c "import pypdf; print(pypdf.__version__)" 2>/dev/null || echo "installed")
                            log_success "pypdf installed successfully (--break-system-packages, version: $PYPDF_VERSION)"
                        else
                            log_error "pypdf installation failed - cannot import after install"
                            log_info "Check log: /tmp/pypdf-install.log"
                            exit 1
                        fi
                    else
                        log_error "pypdf installation failed"
                        log_info "Check log: /tmp/pypdf-install.log"
                        log_info ""
                        log_info "Try manually:"
                        log_info "  pip3 install --user pypdf"
                        log_info "  or: pip3 install --break-system-packages pypdf"
                        exit 1
                    fi
                fi
            fi
            
            # Install reportlab
            if [ "$REPORTLAB_INSTALLED" = false ]; then
                log_info "Installing reportlab via pip..."
                
                # Try --user first (an toàn nhất)
                log_info "Trying pip3 install --user reportlab..."
                if pip3 install --user reportlab 2>&1 | tee /tmp/reportlab-install.log; then
                    if python3 -c "import reportlab" 2>/dev/null; then
                        REPORTLAB_VERSION=$(python3 -c "import reportlab; print(reportlab.Version)" 2>/dev/null || echo "installed")
                        log_success "reportlab installed successfully (--user, version: $REPORTLAB_VERSION)"
                    else
                        log_warning "--user install completed but cannot import, trying --break-system-packages..."
                        if pip3 install --break-system-packages reportlab 2>&1 | tee /tmp/reportlab-install.log; then
                            if python3 -c "import reportlab" 2>/dev/null; then
                                REPORTLAB_VERSION=$(python3 -c "import reportlab; print(reportlab.Version)" 2>/dev/null || echo "installed")
                                log_success "reportlab installed successfully (--break-system-packages, version: $REPORTLAB_VERSION)"
                            else
                                log_error "reportlab installation failed - cannot import after install"
                                log_info "Check log: /tmp/reportlab-install.log"
                                exit 1
                            fi
                        else
                            log_error "reportlab installation failed"
                            log_info "Check log: /tmp/reportlab-install.log"
                            exit 1
                        fi
                    fi
                else
                    # --user failed, try --break-system-packages
                    log_warning "--user install failed (externally-managed-environment), trying --break-system-packages..."
                    if pip3 install --break-system-packages reportlab 2>&1 | tee /tmp/reportlab-install.log; then
                        if python3 -c "import reportlab" 2>/dev/null; then
                            REPORTLAB_VERSION=$(python3 -c "import reportlab; print(reportlab.Version)" 2>/dev/null || echo "installed")
                            log_success "reportlab installed successfully (--break-system-packages, version: $REPORTLAB_VERSION)"
                        else
                            log_error "reportlab installation failed - cannot import after install"
                            log_info "Check log: /tmp/reportlab-install.log"
                            exit 1
                        fi
                    else
                        log_error "reportlab installation failed"
                        log_info "Check log: /tmp/reportlab-install.log"
                        log_info ""
                        log_info "Try manually:"
                        log_info "  pip3 install --user reportlab"
                        log_info "  or: pip3 install --break-system-packages reportlab"
                        exit 1
                    fi
                fi
            fi
        else
            log_error "pip3 not found. Cannot install Python dependencies."
            exit 1
        fi
    fi
else
    log_info "Skipping Python dependencies build (--skip-python)"
fi

# Summary
log_step "Build Summary"
log_success "All dependencies built successfully!"
echo ""
log_info "Installation locations:"
if [ "$SKIP_CUPS" = false ]; then
    log_info "  IPP Tools: $BUILD_PREFIX/bin/ and $BUILD_PREFIX/sbin/"
    log_info "  Libraries: $BUILD_PREFIX/lib/"
fi
if [ "$SKIP_PYTHON" = false ]; then
    log_info "  Python deps: Check with 'python3 -c \"import pypdf, reportlab\"'"
fi
echo ""
log_info "To use IPP tools, add to PATH:"
log_info "  export PATH=\"$BUILD_PREFIX/bin:$BUILD_PREFIX/sbin:\$PATH\""
echo ""
