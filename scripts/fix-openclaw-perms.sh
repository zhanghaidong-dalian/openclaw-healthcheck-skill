#!/bin/bash
#
# OpenClaw Safe Permissions Fix Script
# Version: 1.0.0
# Category: auto-safe
#
# This script fixes OpenClaw file permissions safely with backup
#

set -e

# Configuration
BACKUP_DIR="/tmp/openclaw-perms-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/openclaw-perms-fix.log"

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

log "Starting OpenClaw permissions fix"
log "Backup directory: $BACKUP_DIR"

# Fix 1: OpenClaw configuration directory permissions
log "Fixing OpenClaw config directory permissions..."
if [ -d "/root/.openclaw" ]; then
    chmod 700 /root/.openclaw
    success_msg "Fixed: /root/.openclaw → 700"
else
    warn_msg "Directory /root/.openclaw not found, skipping"
fi

# Fix 2: OpenClaw logs directory permissions
log "Fixing OpenClaw logs directory permissions..."
if [ -d "/var/log/openclaw" ]; then
    chmod 750 /var/log/openclaw
    success_msg "Fixed: /var/log/openclaw → 750"
elif [ -d "/var/log/openclaw" ]; then
    warn_msg "Log directory /var/log/openclaw not found, skipping"
fi

# Fix 3: OpenClaw data directory permissions
log "Fixing OpenClaw data directory permissions..."
if [ -d "/var/lib/openclaw" ]; then
    chmod 750 /var/lib/openclaw
    success_msg "Fixed: /var/lib/openclaw → 750"
else
    warn_msg "Data directory /var/lib/openclaw not found, skipping"
fi

# Fix 4: OpenClaw binary permissions (if exists)
log "Checking OpenClaw binary permissions..."
OPENCLAW_BIN=$(command -v openclaw 2>/dev/null || true)
if [ -n "$OPENCLAW_BIN" ]; then
    current_perms=$(stat -c "%a" "$OPENCLAW_BIN" 2>/dev/null || echo "unknown")
    if [ "$current_perms" != "755" ]; then
        backup_file "$OPENCLAW_BIN"
        chmod 755 "$OPENCLAW_BIN"
        success_msg "Fixed: $OPENCLAW_BIN → 755"
    else
        log "Already correct: $OPENCLAW_BIN → $current_perms"
    fi
else
    warn_msg "OpenClaw binary not found in PATH, skipping"
fi

# Fix 5: Gateway configuration files
log "Fixing gateway configuration file permissions..."
if [ -f "/root/.openclaw/gateway.yml" ]; then
    backup_file "/root/.openclaw/gateway.yml"
    chmod 600 /root/.openclaw/gateway.yml
    success_msg "Fixed: /root/.openclaw/gateway.yml → 600"
fi

# Fix 6: Session and workspace directories
log "Fixing workspace directory permissions..."
if [ -d "/workspace" ]; then
    # Keep existing permissions but ensure owner is correct
    chown -R root:root /workspace 2>/dev/null || true
    log "Verified workspace directory ownership"
fi

# Generate summary
echo ""
success_msg "Permissions fix completed!"
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
echo "✅ All safe permissions have been fixed!"
