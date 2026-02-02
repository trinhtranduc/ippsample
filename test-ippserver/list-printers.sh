#!/bin/bash
#
# Script đơn giản để list printers trong CUPS và xóa nếu cần
# Chỉ monitor và hiển thị, có option để xóa
#
# Usage:
#   ./list-printers.sh              # List tất cả printers
#   ./list-printers.sh remove <name> # Xóa printer
#   ./list-printers.sh watch         # Monitor liên tục
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CHECK_INTERVAL="${CHECK_INTERVAL:-2}"  # Check interval cho watch mode

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
        log_error "CUPS is not running"
        log_info "Start CUPS: sudo launchctl start org.cups.cupsd"
        exit 1
    fi
}

# List all printers
list_printers() {
    log_info "Printers in CUPS:"
    echo ""
    
    local printers=$(lpstat -p 2>/dev/null | awk '{print $2}' | grep -v "^$" | sort || true)
    
    if [ -z "$printers" ]; then
        echo "  (No printers found)"
        return 0
    fi
    
    local count=0
    while IFS= read -r printer; do
        [ -z "$printer" ] && continue
        ((count++))
        
        # Get printer status
        local status=$(lpstat -p "$printer" 2>/dev/null | head -1 | awk '{print $3, $4, $5}' || echo "unknown")
        local uri=$(lpstat -p "$printer" -o 2>/dev/null | head -1 | awk '{print $NF}' || echo "unknown")
        
        echo -e "${CYAN}Printer #$count:${NC} $printer"
        echo -e "  ${BLUE}Status:${NC} $status"
        echo -e "  ${BLUE}URI:${NC} $uri"
        echo ""
    done <<< "$printers"
    
    echo -e "${GREEN}Total: $count printer(s)${NC}"
    return 0
}

# Show detailed info for a printer
show_printer_info() {
    local printer_name="$1"
    
    if ! lpstat -p "$printer_name" > /dev/null 2>&1; then
        log_error "Printer '$printer_name' not found"
        return 1
    fi
    
    log_info "Printer Information: $printer_name"
    echo ""
    lpstat -p "$printer_name" -l | head -20
    echo ""
    
    # Show jobs if any
    local jobs=$(lpstat -o "$printer_name" 2>/dev/null | wc -l | xargs)
    if [ "$jobs" -gt 0 ]; then
        log_info "Print jobs: $jobs"
        lpstat -o "$printer_name" | head -5
    fi
}

# Remove printer
remove_printer() {
    local printer_name="$1"
    
    if [ -z "$printer_name" ]; then
        log_error "Printer name is required"
        echo "Usage: $0 remove <printer-name>"
        return 1
    fi
    
    if ! lpstat -p "$printer_name" > /dev/null 2>&1; then
        log_error "Printer '$printer_name' not found"
        return 1
    fi
    
    log_warning "Removing printer: $printer_name"
    
    # Show info before removing
    show_printer_info "$printer_name"
    
    # Confirm
    read -p "Are you sure you want to remove this printer? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled"
        return 0
    fi
    
    # Reject jobs
    cupsreject "$printer_name" 2>/dev/null || true
    
    # Disable printer
    cupsdisable "$printer_name" 2>/dev/null || true
    
    # Remove printer
    if lpadmin -x "$printer_name" 2>/dev/null; then
        log_success "Printer '$printer_name' removed successfully"
        return 0
    else
        log_error "Failed to remove printer '$printer_name'"
        return 1
    fi
}

# Watch mode - monitor printers continuously
watch_printers() {
    log_info "Watching printers (press Ctrl+C to stop)..."
    log_info "Check interval: ${CHECK_INTERVAL}s"
    echo ""
    
    local last_count=0
    
    while true; do
        local printers=$(lpstat -p 2>/dev/null | awk '{print $2}' | grep -v "^$" | sort || true)
        local current_count=0
        
        if [ -n "$printers" ]; then
            current_count=$(echo "$printers" | grep -v '^[[:space:]]*$' | wc -l | xargs)
            current_count=$(echo "$current_count" | tr -d '[:space:]')
        fi
        
        if ! [[ "$current_count" =~ ^[0-9]+$ ]]; then
            current_count=0
        fi
        
        # Clear screen and show current state
        clear
        echo "=========================================="
        echo "  Printer Monitor - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=========================================="
        echo ""
        
        if [ "$current_count" -ne "$last_count" ]; then
            if [ "$current_count" -gt "$last_count" ]; then
                log_warning "New printer(s) detected! (Count: $last_count -> $current_count)"
            else
                log_info "Printer removed (Count: $last_count -> $current_count)"
            fi
            echo ""
        fi
        
        list_printers
        
        echo ""
        echo "Press Ctrl+C to stop"
        echo "Refresh every ${CHECK_INTERVAL}s..."
        
        last_count=$current_count
        sleep "$CHECK_INTERVAL"
    done
}

# Main
main() {
    check_cups
    
    case "${1:-list}" in
        list|ls)
            list_printers
            ;;
        info|show)
            if [ -z "$2" ]; then
                log_error "Printer name is required"
                echo "Usage: $0 info <printer-name>"
                exit 1
            fi
            show_printer_info "$2"
            ;;
        remove|rm|delete)
            remove_printer "$2"
            ;;
        watch|monitor)
            watch_printers
            ;;
        help|--help|-h)
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  list, ls              List all printers (default)"
            echo "  info, show <name>     Show detailed info for a printer"
            echo "  remove, rm <name>    Remove a printer"
            echo "  watch, monitor       Monitor printers continuously"
            echo ""
            echo "Environment Variables:"
            echo "  CHECK_INTERVAL       Check interval for watch mode (seconds, default: 2)"
            echo ""
            echo "Examples:"
            echo "  $0                    # List all printers"
            echo "  $0 list               # List all printers"
            echo "  $0 info ippserver     # Show info for 'ippserver'"
            echo "  $0 remove virtual-printer  # Remove 'virtual-printer'"
            echo "  $0 watch              # Monitor continuously"
            echo "  CHECK_INTERVAL=5 $0 watch  # Monitor with 5s interval"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use: $0 help"
            exit 1
            ;;
    esac
}

# Signal handler for watch mode
trap 'echo ""; log_info "Stopped"; exit 0' SIGINT SIGTERM

main "$@"
