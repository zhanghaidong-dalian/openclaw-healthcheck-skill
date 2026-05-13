#!/bin/bash
# fix-ssh-hardening.sh - SSH security hardening
# Category: auto-risk (requires confirmation)
# Risk Level: 🟡 Medium
# v4.8.0

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/openclaw-ssh-backup-${TIMESTAMP}"
LOG_FILE="/tmp/openclaw-ssh-fix.log"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

info() { log "${GREEN}[INFO]${NC} $1"; }
warn() { log "${YELLOW}[WARN]${NC} $1"; }
error() { log "${RED}[ERROR]${NC} $1"; }

info "Starting SSH hardening..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_D="/etc/ssh/sshd_config.d"

# Backup current configuration
if [[ -f $SSHD_CONFIG ]]; then
    cp "$SSHD_CONFIG" "$BACKUP_DIR/sshd_config.backup"
    info "Backed up $SSHD_CONFIG"
fi

# Check current SSH config
info "Current SSH security settings:"
echo "---"

# SSH Port
CURRENT_PORT=$(grep -E "^Port " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' || echo "22")
echo "Port: $CURRENT_PORT"

# Password Authentication
PASS_AUTH=$(grep -E "^PasswordAuthentication " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' || echo "yes")
echo "PasswordAuthentication: $PASS_AUTH"

# PermitRootLogin
ROOT_LOGIN=$(grep -E "^PermitRootLogin " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' || echo "prohibit-password")
echo "PermitRootLogin: $ROOT_LOGIN"

# PubkeyAuthentication
PUBKEY=$(grep -E "^PubkeyAuthentication " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' || echo "yes")
echo "PubkeyAuthentication: $PUBKEY"

echo "---"

# Hardening recommendations
info "Hardening recommendations:"
echo ""
echo "1. SSH Port: Current=$CURRENT_PORT, Recommended=<2222 for non-standard>"
echo "2. PasswordAuthentication: Current=$PASS_AUTH, Recommended=no (use keys only)"
echo "3. PermitRootLogin: Current=$ROOT_LOGIN, Recommended=prohibit-password or no"
echo "4. PubkeyAuthentication: Current=$PUBKEY, Recommended=yes"
echo ""

# Check if public key exists
if [[ -f ~/.ssh/id_rsa.pub ]] || [[ -f ~/.ssh/id_ed25519.pub ]]; then
    info "Public key found. SSH key-based login is available."
else
    warn "No public key found. Consider generating one with: ssh-keygen -t ed25519"
fi

info ""
info "To apply SSH hardening manually, edit $SSHD_CONFIG:"
echo ""
echo "  # Change SSH port (optional)"
echo "  Port 2222"
echo ""
echo "  # Disable password authentication"
echo "  PasswordAuthentication no"
echo "  ChallengeResponseAuthentication no"
echo ""
echo "  # Restrict root login"
echo "  PermitRootLogin prohibit-password"
echo ""
echo "  # Ensure pubkey auth is enabled"
echo "  PubkeyAuthentication yes"
echo ""
echo "  # Reload SSH after changes"
echo "  sudo systemctl reload sshd"
echo ""

info "SSH hardening scan complete!"
info "Log file: $LOG_FILE"
info "Backup directory: $BACKUP_DIR"

echo ""
echo "=========================================="
echo "⚠️  IMPORTANT - Before Hardening:"
echo "=========================================="
echo "1. Ensure you have SSH key access configured"
echo "2. Test SSH key login in another terminal"
echo "3. Keep current terminal open as backup"
echo "4. Restart SSH: sudo systemctl reload sshd"
echo "=========================================="
