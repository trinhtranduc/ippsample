#!/bin/bash
#
# Script chính để setup và start ippserver
# - Tạo ippserver configuration
# - Start ippserver process
# - Setup watermark (nếu cần)
#
# Usage:
#   ./setup-ippserver.sh                    # Start với default settings
#   ./setup-ippserver.sh 192.168.1.100      # Start với custom IP
#   ./setup-ippserver.sh --printer-name my-printer
#   ./setup-ippserver.sh --stop             # Stop ippserver
#   ./setup-ippserver.sh --status           # Check status
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load unified logging
if [ -f "$SCRIPT_DIR/unified-logger.sh" ]; then
    source "$SCRIPT_DIR/unified-logger.sh"
    _SCRIPT_NAME="ippserver"
else
    # Fallback logging
    log_info() { echo "[INFO] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
fi

# Configuration
PORT="${PORT:-8631}"
PRINTER_NAME="${PRINTER_NAME:-ippserver}"
BUILD_PREFIX="${BUILD_PREFIX:-$HOME/local}"

# Setup environment
if [ -f "$SCRIPT_DIR/setup-local-env.sh" ]; then
    source "$SCRIPT_DIR/setup-local-env.sh"
fi

# Check ippserver
if ! command -v ippserver &>/dev/null; then
    log_error "ippserver not found in PATH"
    log_info "Please run: ./build-all.sh first"
    exit 1
fi

# Parse arguments
ACTION="start"
CUSTOM_HOSTNAME=""
NO_DNS_SD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stop)
            ACTION="stop"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        --printer-name=*)
            PRINTER_NAME="${1#*=}"
            shift
            ;;
        --printer-name)
            PRINTER_NAME="$2"
            shift 2
            ;;
        --no-dns-sd)
            NO_DNS_SD="--no-dns-sd"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [HOSTNAME]"
            echo ""
            echo "Options:"
            echo "  --stop              Stop ippserver"
            echo "  --status            Check ippserver status"
            echo "  --printer-name NAME Set printer name"
            echo "  --no-dns-sd         Disable Bonjour/DNS-SD"
            echo "  --help, -h          Show this help"
            exit 0
            ;;
        *)
            if [ -z "$CUSTOM_HOSTNAME" ]; then
                CUSTOM_HOSTNAME="$1"
            fi
            shift
            ;;
    esac
done

# Detect hostname/IP
detect_hostname() {
    if [ -n "$CUSTOM_HOSTNAME" ]; then
        HOSTNAME="$CUSTOM_HOSTNAME"
        log_info "Using hostname from command line: $HOSTNAME"
    elif [ -n "$HOSTNAME" ]; then
        log_info "Using HOSTNAME from environment: $HOSTNAME"
    else
        # Auto-detect
        SYSTEM_HOSTNAME=$(hostname 2>/dev/null || echo "")
        IP_ADDRESS=""
        
        for interface in en0 en1 en2 en3; do
            IP_ADDRESS=$(ipconfig getifaddr "$interface" 2>/dev/null)
            if [ -n "$IP_ADDRESS" ] && [ "$IP_ADDRESS" != "127.0.0.1" ]; then
                break
            fi
        done
        
        if [ -n "$IP_ADDRESS" ] && [ "$IP_ADDRESS" != "127.0.0.1" ]; then
            HOSTNAME="$IP_ADDRESS"
        elif [ -n "$SYSTEM_HOSTNAME" ] && [ "$SYSTEM_HOSTNAME" != "localhost" ]; then
            HOSTNAME="$SYSTEM_HOSTNAME"
        else
            HOSTNAME="localhost"
        fi
        
        log_info "Auto-detected hostname: $HOSTNAME"
    fi
}

# Stop ippserver
stop_ippserver() {
    log_info "Stopping ippserver..."
    
    local pid=$(lsof -ti :$PORT 2>/dev/null || true)
    if [ -n "$pid" ]; then
        log_info "Found ippserver on port $PORT (PID: $pid)"
        kill $pid 2>/dev/null || true
        sleep 2
        
        if ps -p $pid >/dev/null 2>&1; then
            kill -9 $pid 2>/dev/null || true
            sleep 1
        fi
        
        if ! ps -p $pid >/dev/null 2>&1; then
            log_info "ippserver stopped"
            return 0
        else
            log_error "Failed to stop ippserver"
            return 1
        fi
    else
        log_info "No ippserver running on port $PORT"
        return 0
    fi
}

# Check status
check_status() {
    log_info "Checking ippserver status..."
    
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        local pid=$(lsof -ti :$PORT)
        log_info "✅ ippserver is running"
        log_info "   Port: $PORT"
        log_info "   PID: $pid"
        log_info "   Printer URI: ipp://$HOSTNAME:$PORT/ipp/print/$PRINTER_NAME"
        return 0
    else
        log_info "❌ ippserver is not running"
        return 1
    fi
}

# Start ippserver
start_ippserver() {
    detect_hostname
    
    # Check if already running
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "ippserver is already running on port $PORT"
        log_info "Use './setup-ippserver.sh --stop' to stop it first"
        return 1
    fi
    
    # Check Python dependencies if watermark is enabled
    IPPPRINTER_CONF="$SCRIPT_DIR/print/ippprinter.conf"
    if [ -f "$IPPPRINTER_CONF" ]; then
        if grep -q "^Command" "$IPPPRINTER_CONF" && ! grep -q "^#Command" "$IPPPRINTER_CONF"; then
            if ! python3 -c "import pypdf, reportlab" 2>/dev/null; then
                log_warning "pypdf or reportlab not found. Watermark may not work."
                log_info "Run: ./build-all.sh to install dependencies"
            fi
        fi
    fi
    
    log_info "Starting ippserver..."
    log_info "  Port: $PORT"
    log_info "  Printer: $PRINTER_NAME"
    log_info "  Hostname: $HOSTNAME"
    log_info "  URI: ipp://$HOSTNAME:$PORT/ipp/print/$PRINTER_NAME"
    echo ""
    
    # Start ippserver
    ippserver -C "$SCRIPT_DIR" -p "$PORT" -k -r _print $NO_DNS_SD &
    local pid=$!
    
    sleep 2
    
    if ps -p $pid >/dev/null 2>&1; then
        log_info "✅ ippserver started successfully (PID: $pid)"
        log_info ""
        log_info "Printer URI: ipp://$HOSTNAME:$PORT/ipp/print/$PRINTER_NAME"
        log_info ""
        log_info "To add printer to CUPS:"
        log_info "  lpadmin -p $PRINTER_NAME -E -v ipp://$HOSTNAME:$PORT/ipp/print/$PRINTER_NAME -m everywhere"
        return 0
    else
        log_error "Failed to start ippserver"
        return 1
    fi
}

# Main
case "$ACTION" in
    stop)
        stop_ippserver
        ;;
    status)
        detect_hostname
        check_status
        ;;
    start)
        start_ippserver
        ;;
    *)
        log_error "Unknown action: $ACTION"
        exit 1
        ;;
esac
