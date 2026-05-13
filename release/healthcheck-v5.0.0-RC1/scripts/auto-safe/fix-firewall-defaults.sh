#!/bin/bash
# fix-firewall-defaults.sh - Basic firewall configuration
# Category: auto-risk (requires confirmation)
# Risk Level: 🟡 Medium
# v4.8.0

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/openclaw-firewall-backup-${TIMESTAMP}"
LOG_FILE="/tmp/openclaw-firewall-fix.log"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

info() { log "${GREEN}[INFO]${NC} $1"; }
warn() { log "${YELLOW}[WARN]${NC} $1"; }
error() { log "${RED}[ERROR]${NC} $1"; }

info "Starting firewall defaults configuration..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Detect OS and firewall
detect_firewall() {
    if command -v ufw &> /dev/null; then
        echo "ufw"
    elif command -v firewall-cmd &> /dev/null; then
        echo "firewalld"
    elif command -v iptables-save &> /dev/null; then
        echo "iptables"
    else
        echo "none"
    fi
}

FIREWALL=$(detect_firewall)

case $FIREWALL in
    ufw)
        info "Detected UFW firewall"
        
        # Backup current rules
        sudo ufw status verbose > "$BACKUP_DIR/ufw-status-backup.txt" 2>/dev/null || true
        
        info "Current UFW rules:"
        cat "$BACKUP_DIR/ufw-status-backup.txt"
        
        # Default policy suggestions
        warn "Default policies will be set to:"
        echo "  - Incoming: deny (default)"
        echo "  - Outgoing: allow (default)"
        echo "  - SSH: allow (port 22)"
        
        # Apply defaults (only if not already set)
        if ! grep -q "^Status: active" "$BACKUP_DIR/ufw-status-backup.txt" 2>/dev/null; then
            sudo ufw --force enable
            info "UFW enabled with default policies"
        else
            info "UFW already active, skipping enable"
        fi
        
        # Ensure SSH is allowed
        sudo ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
        sudo ufw allow 2222/tcp comment 'SSH-Alt' 2>/dev/null || true
        
        # Set default deny incoming
        sudo ufw default deny incoming
        
        # Log final status
        sudo ufw status verbose > "$BACKUP_DIR/ufw-status-final.txt"
        info "Firewall configuration complete. See $BACKUP_DIR/ for backup."
        ;;
        
    firewalld)
        info "Detected firewalld"
        
        # Backup current rules
        sudo firewall-cmd --list-all > "$BACKUP_DIR/firewalld-backup.txt" 2>/dev/null || true
        
        # Enable and set defaults
        sudo firewall-cmd --permanent --set-default-zone=drop 2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
        sudo firewall-cmd --reload
        
        info "Firewalld configured with drop default and SSH allowed"
        ;;
        
    iptables)
        info "Detected iptables"
        warn "Manual iptables configuration recommended. Saving current rules..."
        sudo iptables-save > "$BACKUP_DIR/iptables-backup.txt"
        info "Backup saved to $BACKUP_DIR/iptables-backup.txt"
        ;;
        
    none)
        warn "No firewall detected. Consider installing ufw:"
        echo "  sudo apt install ufw && sudo ufw enable"
        ;;
esac

info "Firewall defaults configuration complete!"
info "Log file: $LOG_FILE"
info "Backup directory: $BACKUP_DIR"

echo ""
echo "=========================================="
echo "Rollback Instructions:"
echo "=========================================="
echo "UFW:     sudo ufw disable"
echo "Firewalld: sudo firewall-cmd --reload"
echo "Restore:   sudo iptables-restore < $BACKUP_DIR/iptables-backup.txt"
echo "=========================================="
