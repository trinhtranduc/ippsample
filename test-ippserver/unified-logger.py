#!/usr/bin/env python3
"""
Unified Logging Utility - Tất cả log ghi vào 1 file duy nhất

Vị trí log mặc định: ~/.local/log/ippserver/ippserver.log
Có thể config qua environment variable IPPSERVER_LOG_DIR:
- Không set: ~/.local/log/ippserver/ (mặc định - không cần sudo)
- /var/log/ippserver/ - Production (cần sudo setup)
- /tmp/ippserver/ - Testing (sẽ bị xóa khi reboot)
- ./log/ - Development fallback

Usage:
    # From shell script:
    python3 unified-logger.py --level INFO "This is a message"
    python3 unified-logger.py --level ERROR "This is an error"
    
    # Or as a module:
    python3 -c "from unified_logger import log; log('INFO', 'Message', 'script-name')"
    
    # Custom log directory:
    IPPSERVER_LOG_DIR=/var/log/ippserver python3 unified-logger.py --level INFO "Message"
"""

import sys
import os
import argparse
import platform
from datetime import datetime
from pathlib import Path

# Tên file log thống nhất
UNIFIED_LOG_FILE = "ippserver.log"

# Xác định log directory theo thứ tự ưu tiên
def determine_log_directory():
    """
    Xác định log directory theo thứ tự ưu tiên:
    1. IPPSERVER_LOG_DIR environment variable (nếu set)
    2. /var/log/ippserver/ (production - cần sudo setup)
    3. ~/.local/log/ippserver/ (user-level - không cần sudo)
    4. /tmp/ippserver/ (testing - sẽ bị xóa khi reboot)
    5. ./log/ (development fallback)
    """
    # Option 1: Custom directory từ environment variable
    custom_dir = os.environ.get("IPPSERVER_LOG_DIR")
    if custom_dir:
        return Path(custom_dir).expanduser()
    
    # Option 2: User-level log directory (không cần sudo) - DEFAULT
    user_log_dir = Path.home() / ".local" / "log" / "ippserver"
    
    # Option 3: System log directory (production)
    if platform.system() == "Darwin":  # macOS
        system_log_dir = Path("/private/var/log/ippserver")
    else:  # Linux
        system_log_dir = Path("/var/log/ippserver")
    
    # Option 4: Temporary directory (testing)
    tmp_log_dir = Path("/tmp/ippserver")
    
    # Option 5: Project log directory (fallback)
    project_log_dir = Path(__file__).parent / "log"
    
    # Thử từng option theo thứ tự ưu tiên (user-level first)
    for log_dir in [user_log_dir, system_log_dir, tmp_log_dir, project_log_dir]:
        try:
            log_dir.mkdir(parents=True, exist_ok=True)
            log_file = log_dir / UNIFIED_LOG_FILE
            log_file.touch(exist_ok=True)
            # Test write permission
            with open(log_file, 'a') as f:
                f.write("")
            return log_dir
        except (PermissionError, OSError):
            continue
    
    # Nếu tất cả đều fail, dùng project log directory (should always work)
    project_log_dir.mkdir(parents=True, exist_ok=True)
    return project_log_dir

# Xác định log directory
LOG_DIR = determine_log_directory()
LOG_FILE_PATH = LOG_DIR / UNIFIED_LOG_FILE

# Lưu project log directory để dùng trong fallback
PROJECT_LOG_DIR = Path(__file__).parent / "log"

# Log levels
LEVELS = {
    'DEBUG': 0,
    'INFO': 1,
    'WARNING': 2,
    'ERROR': 3
}

# Colors for terminal output
COLORS = {
    'DEBUG': '\033[0;36m',    # Cyan
    'INFO': '\033[0;32m',     # Green
    'WARNING': '\033[1;33m',  # Yellow
    'ERROR': '\033[0;31m',    # Red
    'RESET': '\033[0m'        # Reset
}


def log(level, message, script_name=None):
    """
    Log a message to unified log file
    
    Args:
        level: Log level (DEBUG, INFO, WARNING, ERROR)
        message: Message to log
        script_name: Optional script name for context
    """
    # Normalize level
    level = level.upper()
    if level not in LEVELS:
        level = 'INFO'
    
    # Get timestamp
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    # Format message
    if script_name:
        log_entry = f"[{timestamp}] [{level}] [{script_name}] {message}\n"
    else:
        log_entry = f"[{timestamp}] [{level}] {message}\n"
    
    # Write to unified log file
    try:
        with open(LOG_FILE_PATH, 'a', encoding='utf-8') as f:
            f.write(log_entry)
            f.flush()  # Đảm bảo ghi ngay lập tức
    except Exception as e:
        # Fallback to stderr if file write fails
        print(f"[LOGGER ERROR] Failed to write to {LOG_FILE_PATH}: {e}", file=sys.stderr)
        # Cũng thử ghi vào project log directory
        try:
            fallback_path = PROJECT_LOG_DIR / UNIFIED_LOG_FILE
            PROJECT_LOG_DIR.mkdir(parents=True, exist_ok=True)
            with open(fallback_path, 'a', encoding='utf-8') as f:
                f.write(log_entry)
                f.flush()
        except Exception:
            pass
    
    # Also write to stderr (console) with color if terminal
    if sys.stderr.isatty():
        color = COLORS.get(level, COLORS['RESET'])
        reset = COLORS['RESET']
        print(f"{color}{log_entry.rstrip()}{reset}", file=sys.stderr)
    else:
        print(log_entry.rstrip(), file=sys.stderr)
    
    return 0


def get_log_path():
    """Trả về đường dẫn đến unified log file"""
    return str(LOG_FILE_PATH)


def main():
    """Command-line interface"""
    parser = argparse.ArgumentParser(description='Unified Logging Utility')
    parser.add_argument('--level', '-l', default='INFO', 
                       choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                       help='Log level')
    parser.add_argument('--script-name', '-s', help='Script name for context')
    parser.add_argument('--get-log-path', action='store_true', help='Print log file path and exit')
    parser.add_argument('message', nargs='*', help='Message to log')
    
    args = parser.parse_args()
    
    # Nếu chỉ muốn lấy log path
    if args.get_log_path:
        print(str(LOG_FILE_PATH))
        return 0
    
    # Nếu không có message, không làm gì
    if not args.message:
        return 0
    
    message = ' '.join(args.message)
    return log(args.level, message, args.script_name)


if __name__ == '__main__':
    sys.exit(main())
