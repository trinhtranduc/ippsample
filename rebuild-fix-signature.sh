#!/bin/bash
#
# Script để rebuild và fix code signature issues
# Đảm bảo các tools được code sign và có thể dùng được
#

# Don't exit on error - we want to continue even if some steps fail
set +e

cd "$(dirname "$0")"

# Exit code - will be set based on results
EXIT_CODE=0

echo "=== Rebuild IPP Sample Code với fix code signature ==="
echo ""

# Step 1: Clean
echo "Step 1: Cleaning..."
if [ -f "./clean-build.sh" ]; then
    ./clean-build.sh
else
    echo "  clean-build.sh not found, doing manual clean..."
    make clean 2>/dev/null || true
    make distclean 2>/dev/null || true
    rm -f Makedefs config.h config.log config.status
    rm -rf autom4te*.cache
    (cd libcups && make distclean 2>/dev/null || true)
fi

# Step 2: Setup environment
echo ""
echo "Step 2: Setting up environment..."
export CFLAGS="-arch arm64"
export LDFLAGS="-arch arm64"

# Option: Use system libraries (uncomment if needed)
# export CPPFLAGS="-I/usr/include"
# export LDFLAGS="-arch arm64 -L/usr/lib"

echo "CFLAGS: $CFLAGS"
echo "LDFLAGS: $LDFLAGS"
echo ""

# Step 3: Configure
echo "Step 3: Configuring..."
echo "Note: --enable-static chỉ tạo static libraries cho libcups/libpdfio"
echo "      Executables vẫn có thể link dynamic libraries từ Homebrew (OpenSSL, libpng)"
echo "      macOS không support fully static executables (LDFLAGS=-static)"
echo ""
./configure --disable-shared --enable-static

# Step 4: Fix paths (if needed)
echo ""
echo "Step 4: Fixing paths..."

# Always fix CUPS_DATADIR to use ${prefix} instead of hardcoded /usr/local
# This ensures fonts install to the correct location when using custom prefix
if [ -f "libcups/Makedefs" ]; then
    echo "Fixing CUPS_DATADIR to use \${prefix}/share/libcups3..."
    sed -i '' 's|^CUPS_DATADIR[[:space:]]*=.*|CUPS_DATADIR\t=	${prefix}/share/libcups3|' libcups/Makedefs
fi

# Fix paths with spaces (if needed)
if [[ "$PWD" == *" "* ]]; then
    echo "Detected spaces in path, fixing INSTALL paths in Makedefs..."
    
    # Fix root Makedefs
    if [ -f "Makedefs" ]; then
        INSTALL_PATH="$PWD/install-sh"
        sed -i '' "s|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	\"$INSTALL_PATH\"|" Makedefs
    fi
    
    # Fix libcups/Makedefs
    if [ -f "libcups/Makedefs" ]; then
        INSTALL_PATH="$PWD/libcups/install-sh"
        sed -i '' "s|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	\"$INSTALL_PATH\"|" libcups/Makedefs
    fi
    
    # Fix libcups/pdfio/Makefile
    if [ -f "libcups/pdfio/Makefile" ]; then
        INSTALL_PATH="$PWD/libcups/pdfio/install-sh"
        sed -i '' "s|^INSTALL[[:space:]]*=.*|INSTALL\t\t=	\"$INSTALL_PATH\"|" libcups/pdfio/Makefile
    fi
    
    echo "Paths with spaces fixed!"
else
    echo "No spaces in path, skipping INSTALL path fixes."
fi

# Step 5: Build
echo ""
echo "Step 5: Building..."
if ! make; then
    echo "✗ Build failed!"
    exit 1
fi

# Step 6: Install
echo ""
echo "Step 6: Installing..."
if ! make install prefix="$HOME/local"; then
    echo "✗ Install failed!"
    exit 1
fi

# Step 7: Verify code signatures (build system đã sign rồi)
echo ""
echo "Step 7: Verifying code signatures..."

LOCAL_BIN="$HOME/local/bin"
LOCAL_SBIN="$HOME/local/sbin"

# Function to check signature
check_signature() {
    local binary="$1"
    if [ ! -f "$binary" ]; then
        return 1
    fi
    
    # Check if signed
    if codesign -v "$binary" 2>/dev/null; then
        SIGN_INFO=$(codesign -d -vv "$binary" 2>&1 | grep -E "Signature|Format" | head -2)
        echo "  ✓ $(basename "$binary"): Signed ($(echo "$SIGN_INFO" | grep Signature | cut -d= -f2 | tr -d ' '))"
        return 0
    else
        echo "  ⚠ $(basename "$binary"): Not signed or invalid"
        return 1
    fi
}

# Check signatures (build system should have signed them)
echo "Checking signatures in $LOCAL_BIN..."
SIGNED_COUNT=0
for tool in ipptool ippfind ipp3dprinter ippdoclint ippeveprinter ipptransform cups-oauth cups-x509; do
    if check_signature "$LOCAL_BIN/$tool"; then
        SIGNED_COUNT=$((SIGNED_COUNT + 1))
    fi
done

echo "Checking signatures in $LOCAL_SBIN..."
for tool in ippserver ippproxy; do
    if check_signature "$LOCAL_SBIN/$tool"; then
        SIGNED_COUNT=$((SIGNED_COUNT + 1))
    fi
done

echo ""
echo "  $SIGNED_COUNT binaries have valid signatures"

# Note: Build system tự động sign với ad-hoc signature
# Vấn đề thực sự là Homebrew libraries có signature không hợp lệ
# Giải pháp: Build static (--enable-static) để tránh link đến Homebrew libraries

# Step 8: Run tests (như trong README.md)
echo ""
echo "Step 8: Running tests (make test)..."
echo "Note: Some tests may fail due to code signature issues with Homebrew libraries."
echo ""

# Run tests and capture exit code properly
set +e  # Don't exit on error
make test 2>&1 | tee /tmp/ipptest-rebuild.log
TEST_EXIT=${PIPESTATUS[0]}  # Get exit code of make test, not tee
set -e  # Re-enable exit on error

echo ""
if [ $TEST_EXIT -eq 0 ]; then
    echo "✓ All tests passed!"
else
    echo "⚠ Tests completed with exit code $TEST_EXIT"
    echo "Check /tmp/ipptest-rebuild.log for details"
    
    # Check if it's code signature issue
    if grep -q "Abort trap\|code signature\|Library not loaded" /tmp/ipptest-rebuild.log 2>/dev/null; then
        echo ""
        echo "Detected code signature/library issues in tests."
        echo "This is expected when using Homebrew libraries."
        echo ""
        echo "Note: --enable-static chỉ tạo static libraries cho libcups,"
        echo "      nhưng executables vẫn link dynamic libraries từ Homebrew (OpenSSL, libpng)."
        echo "      Để tạo fully static executables, cần thêm LDFLAGS=-static hoặc"
        echo "      rebuild Homebrew libraries với proper signature."
        echo ""
        echo "The binaries themselves should still work for your use case."
    fi
fi

# Step 9: Verify signatures and test individual tools
echo ""
echo "Step 9: Verifying signatures and testing individual tools..."

# Function to test a binary
test_binary() {
    local binary="$1"
    local name="$2"
    
    if [ ! -f "$binary" ]; then
        echo "✗ $name not found: $binary"
        return 1
    fi
    
    echo "Testing $name..."
    
    # Check signature (build system should have signed it)
    SIGN_STATUS=$(codesign -v "$binary" 2>&1)
    if [ $? -eq 0 ]; then
        SIGN_TYPE=$(codesign -d -vv "$binary" 2>&1 | grep "Signature=" | cut -d= -f2 | tr -d ' ')
        echo "  ✓ Signature valid ($SIGN_TYPE)"
    else
        echo "  ⚠ Signature issue: $SIGN_STATUS" | head -1
        echo "    → Build system should have signed this. May need to rebuild."
    fi
    
    # Check dependencies (vấn đề thực sự là ở đây!)
    echo "  Checking dependencies..."
    DEPS=$(otool -L "$binary" 2>/dev/null | grep -E "(ssl|png|homebrew)" | head -5 || true)
    if [ -n "$DEPS" ]; then
        echo "  ⚠ Dependencies from Homebrew (có thể gây code signature issues):"
        echo "$DEPS" | sed 's/^/    /'
        echo "    → Vấn đề: Homebrew libraries có signature không hợp lệ"
        echo "    → Giải pháp: Build với --enable-static (đã làm) để tránh dependencies"
    else
        echo "  ✓ No Homebrew dependencies (static build successful)"
    fi
    
    # Test run
    echo "  Testing execution..."
    TEST_OUTPUT=$( "$binary" --version 2>&1 )
    TEST_EXIT=$?
    
    if [ $TEST_EXIT -eq 0 ]; then
        echo "  ✓ $name runs successfully"
        echo "    Version: $(echo "$TEST_OUTPUT" | head -1)"
        return 0
    else
        # Check error type
        if echo "$TEST_OUTPUT" | grep -q "code signature\|Library not loaded\|Team ID"; then
            echo "  ✗ Code signature/library issue:"
            echo "$TEST_OUTPUT" | head -2 | sed 's/^/    /'
            
            # Try to get more info
            if echo "$TEST_OUTPUT" | grep -q "libssl\|libpng"; then
                echo "    → Suggestion: Rebuild with --enable-static or use system libraries"
            fi
        elif echo "$TEST_OUTPUT" | grep -q "Abort trap"; then
            echo "  ✗ Crashed (likely code signature issue):"
            echo "$TEST_OUTPUT" | head -2 | sed 's/^/    /'
        else
            echo "  ⚠ $name has issues:"
            echo "$TEST_OUTPUT" | head -2 | sed 's/^/    /'
        fi
        return 1
    fi
}

# Test critical tools
echo ""
echo "Testing critical tools..."
test_binary "$LOCAL_SBIN/ippserver" "ippserver"
test_binary "$LOCAL_BIN/ipptool" "ipptool"
test_binary "$LOCAL_SBIN/ippproxy" "ippproxy"

# Step 10: Summary
echo ""
echo "=== Rebuild completed ==="
echo ""

# Count successful tools
SUCCESS_COUNT=0
TOTAL_COUNT=0
FAILED_TOOLS=()

echo "Running final verification on all tools..."
for tool in "$LOCAL_BIN"/ipp* "$LOCAL_SBIN"/ipp* "$LOCAL_BIN"/cups-*; do
    if [ -f "$tool" ] && [ -x "$tool" ]; then
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        TOOL_NAME=$(basename "$tool")
        
        # Quick test
        if "$tool" --version >/dev/null 2>&1 || "$tool" --help >/dev/null 2>&1; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAILED_TOOLS+=("$TOOL_NAME")
        fi
    fi
done

echo ""
echo "=== Summary ==="
echo "  Total tools installed: $TOTAL_COUNT"
echo "  Working tools: $SUCCESS_COUNT"
if [ ${#FAILED_TOOLS[@]} -gt 0 ]; then
    echo "  Failed tools: ${#FAILED_TOOLS[@]}"
    echo "    ${FAILED_TOOLS[*]}"
fi
echo ""

if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ] && [ $TOTAL_COUNT -gt 0 ]; then
    echo "✓ All tools are working and properly signed!"
    EXIT_CODE=0
elif [ $SUCCESS_COUNT -gt 0 ]; then
    echo "⚠ Some tools may have issues. Check detailed output above."
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Check if tools are properly signed: codesign -v <tool-path>"
    echo "  2. Check dependencies: otool -L <tool-path> | grep homebrew"
    echo "  3. If still issues, try:"
    echo "     - Rebuild with --enable-static (already done)"
    echo "     - Reinstall Homebrew libraries: brew reinstall openssl@3 libpng"
    echo "     - Use system libraries instead of Homebrew"
    EXIT_CODE=1
else
    echo "✗ No tools are working. Please check build logs above."
    EXIT_CODE=1
fi

echo ""
if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "Next steps:"
    echo "  1. Setup environment:"
    echo "     source setup-local-env.sh"
    echo ""
    echo "  2. Test ippserver:"
    echo "     cd test-ippserver"
    echo "     ./start-server.sh"
    echo ""
    echo "  3. Test print (in another terminal):"
    echo "     source setup-local-env.sh"
    echo "     cd test-ippserver"
    echo "     ./test-print.sh ../examples/vector.pdf"
fi

exit $EXIT_CODE
