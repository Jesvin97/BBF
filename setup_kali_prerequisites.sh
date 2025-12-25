#!/bin/bash
# =============================================================================
# Multi-Scanner Vulnerability Assessment Tool - Setup Script for Kali Linux
# =============================================================================
# This script installs and configures all required tools and dependencies
# Run with: sudo bash setup_kali_prerequisites.sh
# =============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[!] Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Multi-Scanner Vulnerability Tool - Kali Linux Setup         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# 1. UPDATE SYSTEM
# =============================================================================
echo -e "${YELLOW}[*] Step 1: Updating system packages...${NC}"
apt-get update -y
apt-get upgrade -y

# =============================================================================
# 2. INSTALL PYTHON DEPENDENCIES
# =============================================================================
echo -e "${YELLOW}[*] Step 2: Installing Python and pip...${NC}"
apt-get install -y python3 python3-pip python3-venv

echo -e "${YELLOW}[*] Installing Python packages...${NC}"
pip3 install --upgrade pip
pip3 install lxml requests python-gvm gvm-tools

# =============================================================================
# 3. INSTALL NIKTO
# =============================================================================
echo -e "${YELLOW}[*] Step 3: Installing Nikto...${NC}"
apt-get install -y nikto

# Update Nikto plugins
echo -e "${GREEN}[+] Updating Nikto plugins...${NC}"
nikto -update || echo -e "${YELLOW}[!] Nikto update failed, continuing...${NC}"

# Verify installation
if command -v nikto &> /dev/null; then
    echo -e "${GREEN}[✓] Nikto installed successfully${NC}"
    nikto -Version
else
    echo -e "${RED}[✗] Nikto installation failed${NC}"
fi

# =============================================================================
# 4. INSTALL OWASP ZAP
# =============================================================================
echo -e "${YELLOW}[*] Step 4: Installing OWASP ZAP...${NC}"

# ZAP is usually pre-installed on Kali, but let's ensure it's there
apt-get install -y zaproxy

# Install ZAP CLI (optional but useful)
echo -e "${GREEN}[+] Installing ZAP CLI...${NC}"
pip3 install zapcli

# Alternative: Install via Snap if not available
if ! command -v zaproxy &> /dev/null; then
    echo -e "${YELLOW}[!] ZAP not found via apt, trying snap...${NC}"
    apt-get install -y snapd
    snap install zaproxy --classic
fi

# Check if Docker is available for ZAP baseline
if command -v docker &> /dev/null; then
    echo -e "${GREEN}[+] Docker detected, pulling OWASP ZAP Docker image...${NC}"
    docker pull owasp/zap2docker-stable
else
    echo -e "${YELLOW}[!] Docker not installed. Install with: apt-get install docker.io${NC}"
fi

if command -v zaproxy &> /dev/null || [ -f "/snap/bin/zaproxy" ]; then
    echo -e "${GREEN}[✓] OWASP ZAP installed successfully${NC}"
else
    echo -e "${RED}[✗] OWASP ZAP installation failed${NC}"
fi

# =============================================================================
# 5. INSTALL W3AF
# =============================================================================
echo -e "${YELLOW}[*] Step 5: Installing w3af...${NC}"

# Install w3af dependencies
apt-get install -y git python3-pip python3-dev libssl-dev \
    python3-yaml python3-lxml python3-setuptools

# Clone w3af repository if not exists
if [ ! -d "/opt/w3af" ]; then
    echo -e "${GREEN}[+] Cloning w3af repository...${NC}"
    cd /opt
    git clone https://github.com/andresriancho/w3af.git
    cd w3af
    
    # Install w3af dependencies
    ./w3af_console || true  # First run installs dependencies
    pip3 install -r requirements.txt || echo -e "${YELLOW}[!] Some w3af dependencies failed${NC}"
    
    # Create symlink
    ln -sf /opt/w3af/w3af_console /usr/local/bin/w3af_console
else
    echo -e "${GREEN}[+] w3af already installed, updating...${NC}"
    cd /opt/w3af
    git pull
fi

if [ -f "/opt/w3af/w3af_console" ]; then
    echo -e "${GREEN}[✓] w3af installed successfully${NC}"
else
    echo -e "${RED}[✗] w3af installation failed${NC}"
fi

# =============================================================================
# 6. INSTALL OPENVAS (GVM)
# =============================================================================
echo -e "${YELLOW}[*] Step 6: Installing OpenVAS (GVM)...${NC}"
echo -e "${YELLOW}[!] Note: OpenVAS setup is complex and time-consuming${NC}"

apt-get install -y gvm
apt-get install -y openvas

# Setup OpenVAS (this takes a while)
echo -e "${GREEN}[+] Setting up OpenVAS... (This may take 15-30 minutes)${NC}"
gvm-setup || echo -e "${YELLOW}[!] OpenVAS setup incomplete, may need manual configuration${NC}"

# Check OpenVAS
gvm-check-setup || echo -e "${YELLOW}[!] OpenVAS needs additional configuration${NC}"

if command -v gvm-cli &> /dev/null; then
    echo -e "${GREEN}[✓] OpenVAS/GVM tools installed${NC}"
else
    echo -e "${RED}[✗] OpenVAS installation failed${NC}"
fi

# =============================================================================
# 7. INSTALL NUCLEI
# =============================================================================
echo -e "${YELLOW}[*] Step 7: Installing Nuclei...${NC}"

# Method 1: Using apt (if available in Kali repos)
apt-get install -y nuclei || {
    echo -e "${YELLOW}[!] Nuclei not in apt, installing via Go...${NC}"
    
    # Install Go if not present
    if ! command -v go &> /dev/null; then
        echo -e "${GREEN}[+] Installing Go...${NC}"
        apt-get install -y golang-go
    fi
    
    # Install Nuclei via Go
    echo -e "${GREEN}[+] Installing Nuclei via Go...${NC}"
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    
    # Add Go bin to PATH if not already there
    export PATH=$PATH:$(go env GOPATH)/bin
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
    
    # Copy to system path
    cp $(go env GOPATH)/bin/nuclei /usr/local/bin/ || true
}

# Update Nuclei templates
echo -e "${GREEN}[+] Updating Nuclei templates...${NC}"
nuclei -update-templates || echo -e "${YELLOW}[!] Template update failed${NC}"

if command -v nuclei &> /dev/null; then
    echo -e "${GREEN}[✓] Nuclei installed successfully${NC}"
    nuclei -version
else
    echo -e "${RED}[✗] Nuclei installation failed${NC}"
fi

# =============================================================================
# 8. INSTALL WPSCAN
# =============================================================================
echo -e "${YELLOW}[*] Step 8: Installing WPScan...${NC}"

# WPScan is usually pre-installed on Kali
apt-get install -y wpscan || {
    echo -e "${YELLOW}[!] Installing WPScan via Ruby gems...${NC}"
    apt-get install -y ruby ruby-dev build-essential libcurl4-openssl-dev libxml2 libxml2-dev \
        libxslt1-dev zlib1g-dev
    gem install wpscan
}

# Update WPScan database
echo -e "${GREEN}[+] Updating WPScan database...${NC}"
wpscan --update || echo -e "${YELLOW}[!] WPScan update failed${NC}"

if command -v wpscan &> /dev/null; then
    echo -e "${GREEN}[✓] WPScan installed successfully${NC}"
    wpscan --version
else
    echo -e "${RED}[✗] WPScan installation failed${NC}"
fi

# =============================================================================
# 9. INSTALL ADDITIONAL UTILITIES
# =============================================================================
echo -e "${YELLOW}[*] Step 9: Installing additional utilities...${NC}"

apt-get install -y curl wget jq nmap

# =============================================================================
# 10. CREATE WORKING DIRECTORY
# =============================================================================
echo -e "${YELLOW}[*] Step 10: Setting up working directory...${NC}"

mkdir -p /opt/vulnerability-scanner
cd /opt/vulnerability-scanner

# Save the Python script
cat > /opt/vulnerability-scanner/scanner.py << 'EOFSCRIPT'
# Paste the entire scanner.py script content here
# For now, we'll create a placeholder
echo "Place your scanner.py script here"
EOFSCRIPT

chmod +x /opt/vulnerability-scanner/scanner.py

# Create output directory
mkdir -p /opt/vulnerability-scanner/reports

echo -e "${GREEN}[✓] Working directory created: /opt/vulnerability-scanner${NC}"

# =============================================================================
# 11. VERIFICATION
# =============================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Installation Summary                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check each tool
check_tool() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}[✓] $1${NC}"
        return 0
    else
        echo -e "${RED}[✗] $1 - NOT FOUND${NC}"
        return 1
    fi
}

echo -e "${YELLOW}Tool Availability:${NC}"
check_tool "python3"
check_tool "nikto"
check_tool "zaproxy"
check_tool "w3af_console"
check_tool "gvm-cli"
check_tool "nuclei"
check_tool "wpscan"
check_tool "curl"

# =============================================================================
# 12. CONFIGURATION TIPS
# =============================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Post-Installation Steps                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}1. OpenVAS Configuration:${NC}"
echo "   - Start OpenVAS: sudo gvm-start"
echo "   - Check status: sudo gvm-check-setup"
echo "   - Access web interface: https://localhost:9392"
echo "   - Default credentials are shown during setup"
echo ""

echo -e "${YELLOW}2. Nuclei Configuration:${NC}"
echo "   - Templates location: ~/nuclei-templates/"
echo "   - Update templates: nuclei -update-templates"
echo "   - List templates: nuclei -tl"
echo ""

echo -e "${YELLOW}3. WPScan Configuration (Optional):${NC}"
echo "   - Get API token: https://wpscan.com/register"
echo "   - Configure: wpscan --api-token YOUR_TOKEN"
echo ""

echo -e "${YELLOW}4. Usage Example:${NC}"
echo "   cd /opt/vulnerability-scanner"
echo "   sudo python3 scanner.py https://example.com"
echo "   # Output: vulnerability_report.html"
echo ""

echo -e "${YELLOW}5. Docker Setup (if not installed):${NC}"
echo "   sudo apt-get install docker.io"
echo "   sudo systemctl start docker"
echo "   sudo systemctl enable docker"
echo "   sudo docker pull owasp/zap2docker-stable"
echo ""

# =============================================================================
# 13. CREATE QUICK START SCRIPT
# =============================================================================
cat > /opt/vulnerability-scanner/quickstart.sh << 'EOF'
#!/bin/bash
# Quick start script for vulnerability scanner

echo "=== Multi-Scanner Vulnerability Assessment Tool ==="
echo ""

if [ -z "$1" ]; then
    echo "Usage: ./quickstart.sh <target-url> [output-file]"
    echo "Example: ./quickstart.sh https://example.com my_report.html"
    exit 1
fi

TARGET=$1
OUTPUT=${2:-vulnerability_report.html}

echo "[*] Target: $TARGET"
echo "[*] Output: $OUTPUT"
echo ""
echo "[*] Starting scan... (This may take 15-30 minutes)"
echo ""

python3 /opt/vulnerability-scanner/scanner.py "$TARGET" -o "$OUTPUT"

echo ""
echo "[+] Scan complete! Report saved to: $OUTPUT"
echo "[+] View with: firefox $OUTPUT"
EOF

chmod +x /opt/vulnerability-scanner/quickstart.sh

# =============================================================================
# FINAL MESSAGE
# =============================================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Installation Complete!                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Copy your scanner.py to: /opt/vulnerability-scanner/"
echo "2. Test installation: cd /opt/vulnerability-scanner && ./quickstart.sh"
echo "3. Read documentation for each tool"
echo "4. Configure any API keys (WPScan, etc.)"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "- Always get permission before scanning any target"
echo "- Some scans can be detected as attacks"
echo "- Use responsibly and ethically"
echo "- Keep all tools updated regularly"
echo ""
echo -e "${GREEN}Happy Scanning! 🔒${NC}"
echo ""
