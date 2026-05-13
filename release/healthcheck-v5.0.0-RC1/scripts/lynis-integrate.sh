#!/bin/bash
#
# Lynis Security Scanner Integration for OpenClaw
# Version: 1.0.0
# Phase: 3 - External Security Tools Integration
#
# Integrates Lynis with OpenClaw healthcheck for comprehensive security auditing
#

set -e

# Configuration
LOG_FILE="/tmp/openclaw-lynis-integration.log"
LYNIS_REPORT="/tmp/lynis-report.dat"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log "Starting Lynis integration for OpenClaw"

# Check if Lynis is installed
if ! command -v lynis &> /dev/null; then
    warn "Lynis is not installed"
    read -p "Do you want to install Lynis? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Installing Lynis..."
        
        # Install Lynis
        apt-get update
        apt-get install -y lynis
        
        success "Lynis installed: $(lynis version)"
    else
        warn "Skipping Lynis installation"
        log "You can install Lynis manually:"
        log "  apt-get install lynis"
        log "  or"
        log "  git clone https://github.com/CISOfy/lynis"
        exit 0
    fi
fi

# Create OpenClaw-specific Lynis profile
log "Creating OpenClaw-specific Lynis profile..."

mkdir -p /etc/lynis

cat > /etc/lynis/profile.openclaw << 'EOF'
# Lynis Profile for OpenClaw
# Version: 1.0

# Include all tests except specific exclusions
include=--tests-from-group=system,processes,storage,networking,software,security-services

# Skip tests that may conflict with OpenClaw
skipdbl=TEST-0001,TEST-0020

# Custom test parameters
parameter=--cronjob
parameter=--quiet
parameter=--log-file=/var/log/lynis.log
parameter=--report-file=/tmp/lynis-report.dat

# Enable OpenClaw specific checks
custom_tests=1
EOF

# Create custom test for OpenClaw
mkdir -p /usr/share/lynis/include/custom

cat > /usr/share/lynis/include/custom/openclaw-checks << 'EOF'
#!/bin/bash
#
# OpenClaw-specific security checks for Lynis
#

openclaw_check() {
    Display --text "OpenClaw Security Checks" --result "INFO" --color "BLUE"
    
    # Check OpenClaw installation
    if command -v openclaw &> /dev/null; then
        LogText "OpenClaw is installed"
        Display --text "OpenClaw installation" --result "FOUND" --color "GREEN"
        
        # Check OpenClaw version
        openclaw_version=$(openclaw --version 2>/dev/null || echo "unknown")
        Display --text "OpenClaw version" --result "$openclaw_version" --color "WHITE"
        
        # Check OpenClaw security audit
        if openclaw security audit &> /dev/null; then
            Display --text "OpenClaw security audit" --result "PASS" --color "GREEN"
        else
            Display --text "OpenClaw security audit" --result "WARN" --color "YELLOW"
        fi
        
        # Check OpenClaw config permissions
        if [ -d "/root/.openclaw" ]; then
            config_perms=$(stat -c "%a" /root/.openclaw)
            if [ "$config_perms" = "700" ]; then
                Display --text "OpenClaw config permissions" --result "SECURE" --color "GREEN"
            else
                Display --text "OpenClaw config permissions" --result "WARN ($config_perms)" --color "YELLOW"
            fi
        fi
    else
        Display --text "OpenClaw installation" --result "NOT FOUND" --color "RED"
    fi
}

# Run OpenClaw checks
openclaw_check
EOF

chmod +x /usr/share/lynis/include/custom/openclaw-checks

# Run Lynis audit
log "Running Lynis security audit..."
echo ""
echo -e "${BLUE}=== Lynis Security Scan ===${NC}"
echo ""

lynis audit system --profile /etc/lynis/profile.openclaw

# Extract key findings
echo ""
echo -e "${BLUE}=== OpenClaw Integration Report ===${NC}"
echo ""

if [ -f "$LYNIS_REPORT" ]; then
    echo "📊 Key Security Metrics:"
    echo ""
    
    # Extract hardening index
    hardening_index=$(grep "hardening_index=" "$LYNIS_REPORT" | cut -d'=' -f2)
    echo "   Hardening Index: $hardening_index"
    
    # Extract warnings
    warnings=$(grep -c "warning" "$LYNIS_REPORT" || echo "0")
    echo "   Warnings: $warnings"
    
    # Extract suggestions
    suggestions=$(grep -c "suggestion" "$LYNIS_REPORT" || echo "0")
    echo "   Suggestions: $suggestions"
    
    echo ""
    echo "📄 Full report saved to: $LYNIS_REPORT"
else
    warn "Lynis report not found"
fi

success "Lynis integration completed!"

echo ""
echo "🔍 Next steps:"
echo "   1. Review Lynis report: cat $LYNIS_REPORT"
echo "   2. Address high-priority warnings"
echo "   3. Run Lynis regularly: lynis audit system"
echo "   4. Integrate with OpenClaw: openclaw security audit --deep"
echo ""
echo "📚 Documentation:"
echo "   - Lynis: https://cisofy.com/lynis/"
echo "   - OpenClaw: Use this healthcheck skill"
