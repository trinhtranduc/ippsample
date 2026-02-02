#!/bin/bash
#
# Script để reset printers và cleanup
# - Stop tất cả ippserver processes
# - Remove tất cả printers từ CUPS
# - Cleanup temporary files
#
# Usage:
#   ./reset-all.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
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

# Check CUPS
check_cups() {
    if ! lpstat -r > /dev/null 2>&1; then
        log_warning "CUPS is not running"
        return 1
    fi
    return 0
}

# Stop ippserver processes
stop_ippserver() {
    log_info "Stopping ippserver processes..."
    
    local ports=(8631 8632 8501)
    local stopped=0
    
    for port in "${ports[@]}"; do
        local pid=$(lsof -ti :$port 2>/dev/null || true)
        if [ -n "$pid" ]; then
            log_info "  Stopping process on port $port (PID: $pid)..."
            kill $pid 2>/dev/null || true
            sleep 1
            
            # Force kill if still running
            if ps -p $pid > /dev/null 2>&1; then
                kill -9 $pid 2>/dev/null || true
                sleep 1
            fi
            
            if ! ps -p $pid > /dev/null 2>&1; then
                log_success "  Port $port stopped"
                ((stopped++))
            else
                log_warning "  Port $port still in use"
            fi
        fi
    done
    
    # Also kill any ippserver processes by name
    local ippserver_pids=$(pgrep -f ippserver 2>/dev/null || true)
    if [ -n "$ippserver_pids" ]; then
        echo "$ippserver_pids" | while read -r pid; do
            log_info "  Stopping ippserver process (PID: $pid)..."
            kill $pid 2>/dev/null || true
            sleep 1
            if ps -p $pid > /dev/null 2>&1; then
                kill -9 $pid 2>/dev/null || true
            fi
        done
    fi
    
    if [ $stopped -gt 0 ] || [ -n "$ippserver_pids" ]; then
        log_success "Stopped ippserver processes"
    else
        log_info "No ippserver processes found"
    fi
}

# Remove all printers from CUPS
remove_all_printers() {
    log_info "Removing all printers from CUPS..."
    
    if ! check_cups; then
        log_warning "CUPS is not running, skipping printer removal"
        return 0
    fi
    
    # Get all printers
    local printers=$(lpstat -p 2>/dev/null | awk '{print $2}' | grep -v "^$" || true)
    
    if [ -z "$printers" ]; then
        log_info "No printers found in CUPS"
        return 0
    fi
    
    log_info "Found printers:"
    echo "$printers" | while read -r printer; do
        echo "  - $printer"
    done
    echo ""
    
    # Remove each printer
    local removed=0
    local failed=0
    
    echo "$printers" | while read -r printer; do
        [ -z "$printer" ] && continue
        
        log_info "Removing printer: $printer..."
        
        # Reject jobs
        cupsreject "$printer" 2>/dev/null || true
        
        # Disable printer
        cupsdisable "$printer" 2>/dev/null || true
        
        # Remove printer
        if lpadmin -x "$printer" 2>/dev/null; then
            log_success "  Removed: $printer"
            ((removed++))
        else
            log_warning "  Failed to remove: $printer (may require sudo)"
            ((failed++))
        fi
    done
    
    echo ""
    if [ $removed -gt 0 ]; then
        log_success "Removed $removed printer(s)"
    fi
    if [ $failed -gt 0 ]; then
        log_warning "$failed printer(s) could not be removed (may require sudo)"
    fi
}

# Cleanup temporary files
cleanup_temp_files() {
    log_info "Cleaning up temporary files..."
    
    # Cleanup virtual printer directories
    local temp_dirs=(
        "/tmp/virtual-ipp-printer"
        "/tmp/virtual-printer-output"
        "/tmp/ippserver-output"
    )
    
    local cleaned=0
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_info "  Cleaning: $dir"
            rm -rf "$dir" 2>/dev/null && ((cleaned++)) || true
        fi
    done
    
    # Cleanup spool directories
    local spool_dirs=$(find /tmp -type d -name "ippserver.*" 2>/dev/null | head -5)
    if [ -n "$spool_dirs" ]; then
        echo "$spool_dirs" | while read -r dir; do
            log_info "  Cleaning spool: $dir"
            rm -rf "$dir" 2>/dev/null || true
        done
    fi
    
    if [ $cleaned -gt 0 ]; then
        log_success "Cleaned up temporary files"
    else
        log_info "No temporary files to clean"
    fi
}

# Main
main() {
    echo "=========================================="
    echo "  Reset All"
    echo "=========================================="
    echo ""
    
    # Step 1: Stop ippserver
    stop_ippserver
    echo ""
    
    # Step 2: Remove all printers
    remove_all_printers
    echo ""
    
    # Step 3: Cleanup
    cleanup_temp_files
    echo ""
    
    # Summary
    echo "=========================================="
    log_success "Reset complete!"
    echo ""
    log_info "Next steps:"
    echo "  - Build dependencies: ./build-all.sh"
    echo "  - Start server: ./setup-ippserver.sh"
    echo "  - Setup virtual printer: ./setup-virtual-printer.sh start"
    echo "=========================================="
}

main "$@"
