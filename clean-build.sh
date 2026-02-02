#!/bin/bash
#
# Script để clean build hoàn toàn
#

cd "$(dirname "$0")"

echo "=== Cleaning build artifacts ==="

# Clean main build
echo "Cleaning main build..."
make clean 2>/dev/null || true
make distclean 2>/dev/null || true

# Clean configure artifacts
echo "Cleaning configure artifacts..."
rm -f Makedefs config.h config.log config.status
rm -rf autom4te*.cache

# Clean libcups
if [ -d "libcups" ]; then
    echo "Cleaning libcups..."
    (cd libcups && make clean 2>/dev/null || true)
    (cd libcups && make distclean 2>/dev/null || true)
fi

# Clean libcups/pdfio
if [ -d "libcups/pdfio" ]; then
    echo "Cleaning libcups/pdfio..."
    (cd libcups/pdfio && make clean 2>/dev/null || true)
fi

echo ""
echo "=== Clean completed ==="
echo ""
echo "To rebuild, run:"
echo "  export CFLAGS=\"-arch arm64\""
echo "  export LDFLAGS=\"-arch arm64\""
echo "  ./configure --disable-shared --enable-static"
echo "  make"
echo "  make install prefix=\"\$HOME/local\""
