#!/bin/bash
# Script để commit và push các thay đổi

cd "$(dirname "$0")"

echo "📦 Adding files..."
git add test-ippserver/

echo ""
echo "📋 Status:"
git status --short

echo ""
echo "💾 Committing..."
git commit -m "Refactor: Migrate from PyMuPDF to pypdf + ReportLab

- Migrate watermark.py from PyMuPDF to pypdf + ReportLab
- Add color parameter support with named colors and RGB values
- Update build-all.sh, check-dependencies.sh, watermark.sh, setup-ippserver.sh
- Clean up unnecessary test scripts and documentation files
- Remove 17 unnecessary files (test scripts, old docs, duplicate files)
- Keep only essential scripts: build-all.sh, setup-ippserver.sh, setup-virtual-printer.sh, reset-all.sh"

echo ""
echo "🚀 Pushing to remote..."
git push

echo ""
echo "✅ Done!"
