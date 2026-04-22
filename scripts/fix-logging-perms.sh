#!/bin/bash
#
# OpenClaw Logging Permissions Fix Script
# Version: 1.0.0
# Category: auto-safe
#
# This script fixes logging file permissions safely with backup
#

set -e

# Configuration
BACKUP_DIR="/tmp/openclaw-logging-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/openclaw-logging-fix.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
    log "ERROR: $1"
    exit 1
}

# Success message
success_msg() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "$LOG_FILE"
}

# Warning message
warn_msg() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

# Backup function
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        cp -p "$file" "$BACKUP_DIR/$file"
        log "Backed up: $file"
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error_exit "This script must be run as root or with sudo"
fi

log "Starting OpenClaw logging permissions fix"
log "Backup directory: $BACKUP_DIR"

# Define common log directories and their target permissions
declare -A LOG_DIRS=(
    ["/var/log/openclaw"]=750
    ["/var/log/openclaw/gateway"]=750
    ["/var/log/openclaw/agents"]=750
    ["/var/log/supervisor"]=750
    ["/var/log/openclaw/session"]=750
)

# Fix log directory permissions
for dir in "${!LOG_DIRS[@]}"; do
    target_perms="${LOG_DIRS[$dir]}"
    log "Processing: $dir"

    if [ -d "$dir" ]; then
        current_perms=$(stat -c "%a" "$dir" 2>/dev/null || echo "unknown")

        if [ "$current_perms" != "$target_perms" ]; then
            chmod "$target_perms" "$dir"
            success_msg "Fixed: $dir → $target_perms (was $current_perms)"
        else
            log "Already correct: $dir → $current_perms"
        fi
    else
        log "Directory not found: $dir (will create if needed)"
        mkdir -p "$dir"
        chmod "$target_perms" "$dir"
        success_msg "Created and set: $dir → $target_perms"
    fi
done

# Fix log file permissions in OpenClaw directories
log "Fixing log file permissions..."
if [ -d "/var/log/openclaw" ]; then
    find /var/log/openclaw -type f -name "*.log" -exec chmod 640 {} \; 2>/dev/null || true
    find /var/log/openclaw -type f -name "*.log" -exec chown root:root {} \; 2>/dev/null || true
    success_msg "Fixed permissions for all .log files in /var/log/openclaw"
fi

# Fix supervisor log files
log "Fixing supervisor log files..."
if [ -d "/var/log/supervisor" ]; then
    find /var/log/supervisor -type f -exec chmod 640 {} \; 2>/dev/null || true
    success_msg "Fixed permissions for supervisor log files"
fi

# Check and fix log rotation configuration
log "Checking logrotate configuration..."
LOGROTATE_CONF="/etc/logrotate.d/openclaw"
if [ -f "$LOGROTATE_CONF" ]; then
    current_perms=$(stat -c "%a" "$LOGROTATE_CONF" 2>/dev/null || echo "unknown")
    if [ "$current_perms" != "644" ]; then
        backup_file "$LOGROTATE_CONF"
        chmod 644 "$LOGROTATE_CONF"
        success_msg "Fixed: $LOGROTATE_CONF → 644"
    fi
else
    log "Logrotate config not found at $LOGROTATE_CONF"
    warn_msg "Consider creating logrotate configuration for OpenClaw logs"
fi

# Create logrotate configuration if it doesn't exist
if [ ! -f "$LOGROTATE_CONF" ] && [ -d "/var/log/openclaw" ]; then
    log "Creating basic logrotate configuration..."
    cat > "$LOGROTATE_CONF" << 'EOF'
/var/log/openclaw/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF
    chmod 644 "$LOGROTATE_CONF"
    success_msg "Created logrotate configuration: $LOGROTATE_CONF"
fi

# Verify log directory ownership
log "Verifying log directory ownership..."
for dir in /var/log/openclaw /var/log/openclaw/gateway /var/log/openclaw/agents; do
    if [ -d "$dir" ]; then
        current_owner=$(stat -c "%U:%G" "$dir" 2>/dev/null || echo "unknown")
        if [ "$current_owner" != "root:root" ]; then
            chown -R root:root "$dir"
            success_msg "Fixed ownership: $dir → root:root (was $current_owner)"
        fi
    fi
done

# Generate summary
echo ""
success_msg "Logging permissions fix completed!"
log "=== Summary ==="
log "Backup location: $BACKUP_DIR"
log "Log file: $LOG_FILE"
echo ""
echo "📋 Backup information:"
echo "   Location: $BACKUP_DIR"
echo "   To restore: cp -r $BACKUP_DIR/* /"
echo ""
echo "📄 Log file: $LOG_FILE"
echo ""
echo "✅ All logging permissions have been fixed!"
echo ""
echo "🔄 Next steps:"
echo "   1. Test log rotation: logrotate -f /etc/logrotate.d/openclaw"
echo "   2. Check supervisor logs: tail -f /var/log/supervisor/*.log"
echo "   3. Verify new logs are created with correct permissions"
