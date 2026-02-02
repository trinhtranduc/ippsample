#!/bin/bash
#
# Script tạo máy in ảo (Virtual IPP Printer) để test
# Tạo một IPP server ảo để simulate printer
#
# Usage:
#   ./setup-virtual-printer.sh start    # Start virtual printer
#   ./setup-virtual-printer.sh stop     # Stop virtual printer
#   ./setup-virtual-printer.sh status   # Check status
#   ./setup-virtual-printer.sh restart  # Restart
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIRTUAL_PRINTER_NAME="${VIRTUAL_PRINTER_NAME:-virtual-printer}"
VIRTUAL_PRINTER_PORT="${VIRTUAL_PRINTER_PORT:-8632}"
VIRTUAL_PRINTER_DIR="/tmp/virtual-ipp-printer"
VIRTUAL_PRINTER_OUTPUT="${VIRTUAL_PRINTER_OUTPUT:-/tmp/virtual-printer-output}"
VIRTUAL_PRINTER_LOG="${VIRTUAL_PRINTER_LOG:-/tmp/virtual-printer.log}"
VIRTUAL_PRINTER_PID_FILE="${VIRTUAL_PRINTER_DIR}/.pid"

# Source environment
if [ -f "$SCRIPT_DIR/setup-local-env.sh" ]; then
    source "$SCRIPT_DIR/setup-local-env.sh"
fi

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

check_ippserver() {
    if ! command -v ippserver &> /dev/null; then
        log_error "ippserver not found in PATH"
        log_info "Please run: ./build-all.sh first"
        exit 1
    fi
}

check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Port $port is already in use"
        return 1
    fi
    return 0
}

create_config() {
    log_info "Creating virtual printer configuration..."
    
    mkdir -p "$VIRTUAL_PRINTER_DIR/print"
    mkdir -p "$VIRTUAL_PRINTER_OUTPUT"
    
    cat > "$VIRTUAL_PRINTER_DIR/print/$VIRTUAL_PRINTER_NAME.conf" << EOF
# Virtual IPP Printer Configuration
MAKE "Virtual IPP Printer"
MODEL "Virtual Test Printer"

# Output to file directory
DeviceURI file://$VIRTUAL_PRINTER_OUTPUT

# Output format
OutputFormat application/pdf

# Document format
Attr mimeMediaType document-format-supported application/pdf
Attr mimeMediaType document-format-default application/pdf

# Printer attributes
Attr keyword media-ready na_letter_8.5x11in,iso_a4_210x297mm
Attr integer pages-per-minute 20
Attr keyword print-color-mode-supported monochrome,color
Attr keyword print-color-mode-default color
EOF

    log_success "Configuration created"
}

start_virtual_printer() {
    log_info "Starting virtual IPP printer..."
    
    # Check if already running
    if [ -f "$VIRTUAL_PRINTER_PID_FILE" ]; then
        local pid=$(cat "$VIRTUAL_PRINTER_PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            log_warning "Virtual printer is already running (PID: $pid)"
            return 1
        else
            rm -f "$VIRTUAL_PRINTER_PID_FILE"
        fi
    fi
    
    # Check port
    if ! check_port $VIRTUAL_PRINTER_PORT; then
        log_error "Port $VIRTUAL_PRINTER_PORT is already in use"
        return 1
    fi
    
    # Create config
    create_config
    
    # Start ippserver
    log_info "Starting ippserver on port $VIRTUAL_PRINTER_PORT..."
    ippserver -C "$VIRTUAL_PRINTER_DIR" \
        -p $VIRTUAL_PRINTER_PORT \
        -k \
        -r _print \
        > "$VIRTUAL_PRINTER_LOG" 2>&1 &
    
    local pid=$!
    echo $pid > "$VIRTUAL_PRINTER_PID_FILE"
    
    sleep 2
    
    # Verify
    if ps -p $pid > /dev/null 2>&1; then
        log_success "Virtual IPP printer started!"
        echo "  PID: $pid"
        echo "  Port: $VIRTUAL_PRINTER_PORT"
        echo "  URI: ipp://localhost:$VIRTUAL_PRINTER_PORT/ipp/print/$VIRTUAL_PRINTER_NAME"
        echo "  Output: $VIRTUAL_PRINTER_OUTPUT"
        return 0
    else
        log_error "Failed to start virtual printer"
        log_info "Check log: $VIRTUAL_PRINTER_LOG"
        rm -f "$VIRTUAL_PRINTER_PID_FILE"
        return 1
    fi
}

stop_virtual_printer() {
    log_info "Stopping virtual IPP printer..."
    
    local pid=""
    if [ -f "$VIRTUAL_PRINTER_PID_FILE" ]; then
        pid=$(cat "$VIRTUAL_PRINTER_PID_FILE")
    else
        pid=$(lsof -ti :$VIRTUAL_PRINTER_PORT 2>/dev/null || true)
    fi
    
    if [ -z "$pid" ]; then
        log_warning "Virtual printer is not running"
        return 1
    fi
    
    if ps -p $pid > /dev/null 2>&1; then
        kill $pid 2>/dev/null || true
        sleep 1
        
        if ps -p $pid > /dev/null 2>&1; then
            kill -9 $pid 2>/dev/null || true
            sleep 1
        fi
        
        if ! ps -p $pid > /dev/null 2>&1; then
            log_success "Virtual printer stopped"
            rm -f "$VIRTUAL_PRINTER_PID_FILE"
            return 0
        else
            log_error "Failed to stop virtual printer"
            return 1
        fi
    else
        log_warning "Process $pid is not running"
        rm -f "$VIRTUAL_PRINTER_PID_FILE"
        return 1
    fi
}

status_virtual_printer() {
    log_info "Checking virtual printer status..."
    
    if [ -f "$VIRTUAL_PRINTER_PID_FILE" ]; then
        local pid=$(cat "$VIRTUAL_PRINTER_PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            log_success "Virtual printer is running"
            echo "  PID: $pid"
            echo "  Port: $VIRTUAL_PRINTER_PORT"
            echo "  URI: ipp://localhost:$VIRTUAL_PRINTER_PORT/ipp/print/$VIRTUAL_PRINTER_NAME"
            echo "  Output: $VIRTUAL_PRINTER_OUTPUT"
            
            if lsof -Pi :$VIRTUAL_PRINTER_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
                log_success "Port $VIRTUAL_PRINTER_PORT is listening"
            else
                log_warning "Port $VIRTUAL_PRINTER_PORT is not listening"
            fi
            return 0
        else
            log_warning "PID file exists but process is not running"
            rm -f "$VIRTUAL_PRINTER_PID_FILE"
            return 1
        fi
    else
        log_warning "Virtual printer is not running"
        return 1
    fi
}

# Main
case "${1:-help}" in
    start)
        check_ippserver
        start_virtual_printer
        ;;
    stop)
        stop_virtual_printer
        ;;
    restart)
        stop_virtual_printer
        sleep 1
        check_ippserver
        start_virtual_printer
        ;;
    status)
        status_virtual_printer
        ;;
    help|--help|-h)
        echo "Usage: $0 [start|stop|restart|status]"
        echo ""
        echo "Environment Variables:"
        echo "  VIRTUAL_PRINTER_NAME    Printer name (default: virtual-printer)"
        echo "  VIRTUAL_PRINTER_PORT    Port number (default: 8632)"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  VIRTUAL_PRINTER_PORT=8640 $0 start"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use: $0 help"
        exit 1
        ;;
esac
