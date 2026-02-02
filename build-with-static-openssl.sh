#!/bin/bash
#
# Build ippexample với static OpenSSL để tránh code signature issues
#
# Script này sẽ:
# 1. Build OpenSSL static từ source
# 2. Build ippexample với static OpenSSL
# 3. Install vào ~/local
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
OPENSSL_VERSION="3.3.0"  # Hoặc "master" cho latest
OPENSSL_PREFIX="$HOME/local/openssl-static"
PROJECT_DIR="/Users/trinhtran/Documents/Source Code/ippexample"
INSTALL_PREFIX="$HOME/local"
OPENSSL_SRC_DIR="$HOME/local/src/openssl"

# Check if we're in the right directory
if [ ! -f "$PROJECT_DIR/configure.ac" ]; then
    echo -e "${RED}Error: Project directory not found: $PROJECT_DIR${NC}"
    exit 1
fi

cd "$PROJECT_DIR"

echo -e "${GREEN}=== Building ippexample with Static OpenSSL ===${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is required but not installed${NC}"
    exit 1
fi

if ! command -v make &> /dev/null; then
    echo -e "${RED}Error: make is required but not installed${NC}"
    exit 1
fi

echo "✓ Prerequisites OK"
echo ""

# Step 2: Build OpenSSL static
echo -e "${YELLOW}Step 2: Building OpenSSL static...${NC}"

# Create source directory if needed
mkdir -p "$HOME/local/src"
cd "$HOME/local/src"

# Clone or update OpenSSL
if [ ! -d openssl ]; then
    echo "Cloning OpenSSL repository..."
    git clone https://github.com/openssl/openssl.git
    cd openssl
else
    echo "Updating OpenSSL repository..."
    cd openssl
    git fetch origin
fi

# Checkout specific version or use master
if [ "$OPENSSL_VERSION" != "master" ]; then
    echo "Checking out OpenSSL $OPENSSL_VERSION..."
    git checkout "openssl-$OPENSSL_VERSION" 2>/dev/null || git checkout "$OPENSSL_VERSION" 2>/dev/null || {
        echo -e "${YELLOW}Warning: Version $OPENSSL_VERSION not found, using latest${NC}"
        git checkout master
    }
else
    echo "Using latest OpenSSL (master branch)..."
    git checkout master
    git pull origin master
fi

# Clean previous build
echo "Cleaning previous build..."
make clean 2>/dev/null || true

# Configure OpenSSL for static build
echo "Configuring OpenSSL for static build (ARM64)..."
./Configure darwin64-arm64-cc \
    --prefix="$OPENSSL_PREFIX" \
    --openssldir="$OPENSSL_PREFIX/ssl" \
    no-shared \
    no-tests

# Build OpenSSL
echo "Building OpenSSL (this may take a while)..."
CPU_COUNT=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
make -j"$CPU_COUNT"

# Install OpenSSL
echo "Installing OpenSSL to $OPENSSL_PREFIX..."
make install

echo -e "${GREEN}✓ OpenSSL static build completed${NC}"
echo ""

# Step 3: Clean ippexample build
echo -e "${YELLOW}Step 3: Cleaning ippexample build...${NC}"
cd "$PROJECT_DIR"

# Clean build artifacts
if [ -f Makefile ]; then
    make clean 2>/dev/null || true
fi

# Clean configure artifacts
if [ -f config.log ]; then
    make distclean 2>/dev/null || true
fi

# Clean libcups
if [ -f libcups/Makefile ]; then
    cd libcups
    make clean 2>/dev/null || true
    make distclean 2>/dev/null || true
    cd ..
fi

echo "✓ Clean completed"
echo ""

# Step 4: Configure ippexample with static OpenSSL
echo -e "${YELLOW}Step 4: Configuring ippexample with static OpenSSL...${NC}"

# Setup environment variables
# Use CPPFLAGS for include paths (only OpenSSL, pdfio will be found by configure)
export CFLAGS="-arch arm64"
export CPPFLAGS="-I$OPENSSL_PREFIX/include"
export LDFLAGS="-arch arm64 -L$OPENSSL_PREFIX/lib"
export PKG_CONFIG_PATH="$OPENSSL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "CFLAGS: $CFLAGS"
echo "LDFLAGS: $LDFLAGS"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
echo ""

# Configure
./configure \
    --disable-shared \
    --enable-static \
    --with-tls=openssl

echo -e "${GREEN}✓ Configuration completed${NC}"
echo ""

# Step 5: Fix paths (if needed)
echo -e "${YELLOW}Step 5: Fixing paths with spaces...${NC}"
if [[ "$PWD" == *" "* ]]; then
    echo "Detected spaces in path, fixing Makedefs..."
    
    # Fix root Makedefs
    if [ -f "Makedefs" ]; then
        INSTALL_PATH="$PWD/install-sh"
        sed -i '' "s|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	\"$INSTALL_PATH\"|" Makedefs
    fi
    
    # Fix libcups/Makedefs
    if [ -f "libcups/Makedefs" ]; then
        INSTALL_PATH="$PWD/libcups/install-sh"
        sed -i '' "s|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	\"$INSTALL_PATH\"|" libcups/Makedefs
        # Fix CUPS_DATADIR
        sed -i '' "s|^CUPS_DATADIR[[:space:]]*=.*|CUPS_DATADIR\t=	\${prefix}/share/libcups3|" libcups/Makedefs
    fi
    
    # Fix libcups/pdfio/Makefile
    if [ -f "libcups/pdfio/Makefile" ]; then
        INSTALL_PATH="$PWD/libcups/pdfio/install-sh"
        sed -i '' "s|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	\"$INSTALL_PATH\"|" libcups/pdfio/Makefile
    fi
    
    echo "✓ Path fixes applied"
else
    echo "No spaces in path, skipping path fixes"
fi
echo ""

# Step 6: Build ippexample
echo -e "${YELLOW}Step 6: Building ippexample...${NC}"
make

echo -e "${GREEN}✓ Build completed${NC}"
echo ""

# Step 7: Install
echo -e "${YELLOW}Step 7: Installing to $INSTALL_PREFIX...${NC}"
make install prefix="$INSTALL_PREFIX"

echo -e "${GREEN}✓ Installation completed${NC}"
echo ""

# Step 8: Verify binaries
echo -e "${YELLOW}Step 8: Verifying binaries...${NC}"

LOCAL_BIN="$INSTALL_PREFIX/bin"
LOCAL_SBIN="$INSTALL_PREFIX/sbin"

# Function to verify binary
verify_binary() {
    local binary="$1"
    local name=$(basename "$binary")
    
    if [ ! -f "$binary" ]; then
        echo -e "  ${RED}✗ $name: Not found${NC}"
        return 1
    fi
    
    echo -e "  ${YELLOW}Checking $name...${NC}"
    
    # Check if it's executable
    if [ ! -x "$binary" ]; then
        echo -e "    ${RED}✗ Not executable${NC}"
        return 1
    fi
    
    # Check dependencies - should NOT have Homebrew OpenSSL
    DEPS=$(otool -L "$binary" 2>/dev/null | grep -E "homebrew.*openssl|homebrew.*libpng" || true)
    if [ -n "$DEPS" ]; then
        echo -e "    ${YELLOW}⚠ Still has Homebrew dependencies:${NC}"
        echo "$DEPS" | sed 's/^/      /'
    else
        echo -e "    ${GREEN}✓ No Homebrew OpenSSL/libpng dependencies${NC}"
    fi
    
    # Check if OpenSSL is statically linked (should not appear in otool -L)
    OPENSSL_DEPS=$(otool -L "$binary" 2>/dev/null | grep -E "libssl|libcrypto" || true)
    if [ -z "$OPENSSL_DEPS" ]; then
        echo -e "    ${GREEN}✓ OpenSSL appears to be statically linked${NC}"
    else
        echo -e "    ${YELLOW}⚠ OpenSSL still dynamically linked:${NC}"
        echo "$OPENSSL_DEPS" | sed 's/^/      /'
    fi
    
    # Test execution
    if "$binary" --version > /dev/null 2>&1 || "$binary" --help > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓ Executes successfully${NC}"
        return 0
    else
        echo -e "    ${RED}✗ Execution failed${NC}"
        return 1
    fi
}

echo "Verifying critical tools..."
verify_binary "$LOCAL_SBIN/ippserver"
verify_binary "$LOCAL_BIN/ipptool"
verify_binary "$LOCAL_SBIN/ippproxy"

echo ""

# Step 9: Summary
echo -e "${GREEN}=== Build Summary ===${NC}"
echo ""
echo "OpenSSL static build: $OPENSSL_PREFIX"
echo "ippexample installed to: $INSTALL_PREFIX"
echo ""
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Setup environment:"
echo "     source setup-local-env.sh"
echo ""
echo "  2. Test ippserver:"
echo "     cd test-ippserver"
echo "     ./start-server.sh"
echo ""
echo "  3. Verify no Homebrew dependencies:"
echo "     otool -L ~/local/bin/ipptool | grep homebrew"
echo "     (should return nothing)"
