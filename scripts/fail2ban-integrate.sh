#!/bin/bash
#
# fail2ban Security Tools Integration for OpenClaw
# Version: 1.0.0
# Phase: 3 - External Security Tools Integration
#
# This script integrates fail2ban with OpenClaw healthcheck
#

set -e

# Configuration
LOG_FILE="/tmp/openclaw-fail2ban-integration.log"
CONFIG_DIR="/etc/fail2ban"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root or with sudo"
    exit 1
fi

log "Starting fail2ban integration for OpenClaw"

# Check if fail2ban is installed
if ! command -v fail2ban-server &> /dev/null; then
    warn "fail2ban is not installed"
    read -p "Do you want to install fail2ban? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Installing fail2ban..."
        apt-get update && apt-get install -y fail2ban
        success "fail2ban installed"
    else
        warn "Skipping fail2ban installation"
        exit 0
    fi
fi

# Check if fail2ban is running
if ! systemctl is-active --quiet fail2ban; then
    warn "fail2ban is not running"
    read -p "Do you want to start fail2ban? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl enable fail2ban
        systemctl start fail2ban
        success "fail2ban started"
    fi
fi

# Create OpenClaw-specific jail configuration
log "Creating OpenClaw-specific fail2ban configuration..."

cat > /etc/fail2ban/jail.d/openclaw.conf << 'EOF'
[openclaw-ssh]
enabled = true
port = ssh
filter = openclaw-ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
action = iptables-allports[name=openclaw]

[openclaw-gateway]
enabled = true
port = 8080,8443,3000
filter = openclaw-gateway
logpath = /var/log/openclaw/gateway/*.log
maxretry = 10
bantime = 1800
findtime = 300
action = iptables-allports[name=openclaw-gateway]

[openclaw-api]
enabled = true
port = 8080
filter = openclaw-api
logpath = /var/log/openclaw/api/*.log
maxretry = 20
bantime = 600
findtime = 60
action = iptables-allports[name=openclaw-api]
EOF

# Create OpenClaw filter definitions
mkdir -p /etc/fail2ban/filter.d

# SSH filter for OpenClaw
cat > /etc/fail2ban/filter.d/openclaw-ssh.conf << 'EOF'
[Definition]
failregex = ^%(__prefix_line)sFailed password for .* from <HOST>.*
            ^%(__prefix_line)sROOT LOG REFUSED.* from <HOST>.*
            ^%(__prefix_line)sMaximum authentication attempts exceeded for.* from <HOST>.*
ignoreregex =
EOF

# Gateway filter
cat > /etc/fail2ban/filter.d/openclaw-gateway.conf << 'EOF'
[Definition]
failregex = ^.*\[error\] .* client <HOST>.* unauthorized access$
            ^.*\[warn\] .* repeated login attempts from <HOST>$
            ^.*\[security\] .* brute force attempt from <HOST>$
ignoreregex =
EOF

# API filter
cat > /etc/fail2ban/filter.d/openclaw-api.conf << 'EOF'
[Definition]
failregex = ^.*401 Unauthorized.*from <HOST>$
            ^.*403 Forbidden.*from <HOST>$
            ^.*rate limit exceeded.*from <HOST>$
ignoreregex =
EOF

# Reload fail2ban
systemctl reload fail2ban

# Display status
success "fail2ban integration completed!"
log "Configuration files created:"
log "  - /etc/fail2ban/jail.d/openclaw.conf"
log "  - /etc/fail2ban/filter.d/openclaw-ssh.conf"
log "  - /etc/fail2ban/filter.d/openclaw-gateway.conf"
log "  - /etc/fail2ban/filter.d/openclaw-api.conf"

echo ""
echo "📊 Current fail2ban status:"
fail2ban-client status
echo ""
echo "🔍 To check specific jail:"
echo "   sudo fail2ban-client status openclaw-ssh"
echo "   sudo fail2ban-client status openclaw-gateway"
echo ""
echo "📝 To view banned IPs:"
echo "   sudo fail2ban-client banned openclaw-ssh"
echo ""
echo "🔓 To unban an IP:"
echo "   sudo fail2ban-client set openclaw-ssh unbanip <IP>"
