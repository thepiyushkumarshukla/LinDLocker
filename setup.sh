#!/bin/bash

#############################################################
# LinDLocker Setup Script
# Installs all required dependencies for LinDLocker
#############################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 LinDLocker Setup Script                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ This script must be run as root${NC}"
    echo -e "${YELLOW}Run with: sudo ./setup.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}Installing required dependencies...${NC}"
echo

# Detect package manager and install dependencies
if command -v apt &> /dev/null; then
    echo -e "${GREEN}Detected APT (Debian/Ubuntu)${NC}"
    apt update
    apt install -y cryptsetup rsync pv lsof
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
    
elif command -v yum &> /dev/null; then
    echo -e "${GREEN}Detected YUM (RHEL/CentOS)${NC}"
    yum install -y cryptsetup rsync pv lsof
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
    
elif command -v dnf &> /dev/null; then
    echo -e "${GREEN}Detected DNF (Fedora)${NC}"
    dnf install -y cryptsetup rsync pv lsof
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
    
elif command -v pacman &> /dev/null; then
    echo -e "${GREEN}Detected Pacman (Arch)${NC}"
    pacman -Sy --noconfirm cryptsetup rsync pv lsof
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
    
elif command -v zypper &> /dev/null; then
    echo -e "${GREEN}Detected Zypper (openSUSE)${NC}"
    zypper install -y cryptsetup rsync pv lsof
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
    
else
    echo -e "${RED}✗ Unsupported package manager${NC}"
    echo -e "${YELLOW}Please manually install:${NC}"
    echo -e "  • cryptsetup"
    echo -e "  • rsync"
    echo -e "  • pv"
    echo -e "  • lsof"
    exit 1
fi

echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Setup Completed Successfully!                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${YELLOW}What was installed:${NC}"
echo -e "  ✓ cryptsetup - For LUKS encryption"
echo -e "  ✓ rsync - For secure file transfers"
echo -e "  ✓ pv - For progress visualization"
echo -e "  ✓ lsof - For detecting open files"
echo
echo -e "${BLUE}To make LinDLocker executable:${NC}"
echo -e "  chmod +x lindlocker.sh"
echo
echo -e "${BLUE}To see available commands:${NC}"
echo -e "  sudo ./lindlocker.sh help"
echo