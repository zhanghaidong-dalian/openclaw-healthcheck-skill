#!/bin/bash
# fix-auto-updates.sh - Enable automatic security updates
# Category: auto-risk (requires confirmation)
# Risk Level: 🟡 Medium
# v4.8.0

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/openclaw-updates-backup-${TIMESTAMP}"
LOG_FILE="/tmp/openclaw-updates-fix.log"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

info() { log "${GREEN}[INFO]${NC} $1"; }
warn() { log "${YELLOW}[WARN]${NC} $1"; }
error() { log "${RED}[ERROR]${NC} $1"; }

info "Starting automatic updates configuration..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif command -v apt &> /dev/null; then
        echo "debian"
    elif command -v yum &> /dev/null; then
        echo "rhel"
    elif command -v dnf &> /dev/null; then
        echo "fedora"
    elif command -v pacman &> /dev/null; then
        echo "arch"
    elif [[ "$(uname)" == "Darwin" ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

case $OS in
    debian|ubuntu)
        info "Detected Debian/Ubuntu system"
        
        # Install unattended-upgrades if not present
        if ! command -v unattended-upgrades &> /dev/null; then
            info "Installing unattended-upgrades..."
            apt update
            apt install -y unattended-upgrades
        else
            info "unattended-upgrades already installed"
        fi
        
        # Enable automatic updates
        dpkg-reconfigure -plow unattended-upgrades
        
        # Configure update schedule
        cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::DevRelease "0";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Packages "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
        
        # Enable daily update check
        cat > /etc/apt/apt.conf.d/02periodic << 'EOF'
APT::Periodic::Enable "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Update-Package-Lists "1";
EOF
        
        info "Automatic updates configured for Debian/Ubuntu"
        ;;
        
    rhel|centos|fedora)
        info "Detected RHEL/CentOS/Fedora system"
        
        # Install dnf-automatic for Fedora
        if command -v dnf &> /dev/null; then
            if ! command -v dnf-automatic &> /dev/null; then
                info "Installing dnf-automatic..."
                dnf install -y dnf-automatic
            fi
            
            # Enable and start the service
            systemctl enable dnf-automatic.timer
            systemctl start dnf-automatic.timer
            
            info "dnf-automatic configured for Fedora/RHEL 8+"
        fi
        
        # For CentOS 7 / RHEL 7
        if command -v yum &> /dev/null && [[ ! -f /etc/dnf/dnf.conf ]]; then
            if ! command -v yum-cron &> /dev/null; then
                info "Installing yum-cron..."
                yum install -y yum-cron
            fi
            
            # Configure
            sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf 2>/dev/null || true
            sed -i 's/download_updates = no/download_updates = yes/' /etc/yum/yum-cron.conf 2>/dev/null || true
            
            # Enable and start
            systemctl enable yum-cron
            systemctl start yum-cron
            
            info "yum-cron configured for CentOS 7"
        fi
        ;;
        
    arch)
        info "Detected Arch Linux"
        warn "Arch Linux uses pacman. Consider using 'reflector' for mirror optimization:"
        echo ""
        echo "  # Install reflector"
        echo "  sudo pacman -S reflector"
        echo ""
        echo "  # Set up systemd timer for weekly mirror update"
        echo "  sudo systemctl enable --now reflector.timer"
        echo ""
        echo "  # Enable daily database sync"
        echo "  sudo systemctl enable --now pacman-bg-upgrade.service"
        echo ""
        info "Arch Linux auto-update configuration guidance provided"
        ;;
        
    macos)
        info "Detected macOS"
        
        # Check if softwareupdate is configured
        info "macOS automatic updates are configured via System Preferences"
        echo ""
        echo "Please enable manually:"
        echo "  1. Apple menu → System Preferences → Software Update"
        echo "  2. Check 'Automatically keep my Mac up to date'"
        echo "  3. Click 'Advanced...' and enable all options:"
        echo "     ☑ Check for updates"
        echo "     ☑ Download new updates when available"
        echo "     ☑ Install macOS updates"
        echo "     ☑ Install app updates from the App Store"
        echo ""
        info "For command-line control, consider using 'softwareupdate' cron job"
        ;;
        
    *)
        warn "Unknown OS: $OS. Manual configuration required."
        ;;
esac

info "Automatic updates configuration complete!"
info "Log file: $LOG_FILE"
info "Backup directory: $BACKUP_DIR"

echo ""
echo "=========================================="
echo "Verification Commands:"
echo "=========================================="
case $OS in
    debian|ubuntu)
        echo "Debian/Ubuntu:"
        echo "  systemctl status unattended-upgrades"
        echo "  cat /etc/apt/apt.conf.d/50unattended-upgrades"
        ;;
    rhel|centos|fedora)
        echo "Fedora/RHEL:"
        echo "  systemctl status dnf-automatic.timer"
        echo "  systemctl list-timers dnf-automatic"
        ;;
    *)
        echo "Check your OS documentation for verification commands"
        ;;
esac
echo "=========================================="
