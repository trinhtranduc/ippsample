#!/bin/bash
#
# Unified Logger Wrapper - Tất cả log ghi vào 1 file duy nhất
# Tất cả scripts sẽ ghi log vào: /private/var/log/ippserver/ippserver.log (macOS)
#                               hoặc /var/log/ippserver/ippserver.log (Linux)
#
# Usage: source unified-logger.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGGER_PY="$SCRIPT_DIR/unified-logger.py"

# Script name (tự động detect từ script gọi)
_SCRIPT_NAME=$(basename "${BASH_SOURCE[1]}" .sh 2>/dev/null || echo "script")

# Function để lấy log file path
get_log_path() {
    python3 "$LOGGER_PY" --get-log-path 2>/dev/null || echo "$SCRIPT_DIR/log/ippserver.log"
}

# Logging functions - tất cả ghi vào unified log file
log_debug() {
    python3 "$LOGGER_PY" --level DEBUG --script-name "$_SCRIPT_NAME" "$@" 2>/dev/null || echo "[DEBUG] [$_SCRIPT_NAME] $*" >&2
}

log_info() {
    python3 "$LOGGER_PY" --level INFO --script-name "$_SCRIPT_NAME" "$@" 2>/dev/null || echo "[INFO] [$_SCRIPT_NAME] $*" >&2
}

log_warning() {
    python3 "$LOGGER_PY" --level WARNING --script-name "$_SCRIPT_NAME" "$@" 2>/dev/null || echo "[WARNING] [$_SCRIPT_NAME] $*" >&2
}

log_error() {
    python3 "$LOGGER_PY" --level ERROR --script-name "$_SCRIPT_NAME" "$@" 2>/dev/null || echo "[ERROR] [$_SCRIPT_NAME] $*" >&2
}

# Helper function để vừa echo vừa log
log_echo() {
    local message="$1"
    local level="${2:-INFO}"
    
    # Echo ra console
    echo "$message"
    
    # Log vào unified log file
    python3 "$LOGGER_PY" --level "$level" --script-name "$_SCRIPT_NAME" "$message" 2>/dev/null || true
}

# Function để set log file (compatibility - không làm gì vì dùng unified log)
set_log_file() {
    # Unified logger không cần set log file
    return 0
}

# Function để set log level (compatibility - không làm gì)
set_log_level() {
    return 0
}

# Export log file path để scripts khác có thể dùng
export UNIFIED_LOG_FILE=$(get_log_path)
