#!/bin/bash

#############################################################
# LinDLocker v2.0 - Production-Ready Directory Encryption
# Lock existing directories with military-grade encryption
# Even root cannot access without password
#############################################################

set -e
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
VAULT_DIR="/var/lib/lindlocker"
STORAGE_DIR="$VAULT_DIR/containers"
CONFIG_FILE="$VAULT_DIR/vaults.conf"
LOG_FILE="$VAULT_DIR/lindlocker.log"

# Version
VERSION="2.0"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Check root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}✗ Error: Root privileges required${NC}"
        echo -e "${YELLOW}Run with: sudo $0 $*${NC}"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    for cmd in cryptsetup rsync pv; do
        if ! command -v $cmd &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}✗ Missing required packages: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install with:${NC}"
        
        if command -v apt &> /dev/null; then
            echo "  sudo apt update && sudo apt install -y cryptsetup rsync pv"
        elif command -v yum &> /dev/null; then
            echo "  sudo yum install -y cryptsetup rsync pv"
        elif command -v dnf &> /dev/null; then
            echo "  sudo dnf install -y cryptsetup rsync pv"
        fi
        exit 1
    fi
}

# Initialize
init_vault_dir() {
    mkdir -p "$VAULT_DIR" "$STORAGE_DIR"
    touch "$CONFIG_FILE" "$LOG_FILE"
    chmod 700 "$VAULT_DIR"
    chmod 600 "$CONFIG_FILE" "$LOG_FILE"
}

# Progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Calculate directory size in MB
get_directory_size() {
    local dir="$1"
    local size_mb=$(du -sm "$dir" 2>/dev/null | cut -f1)
    # Add 30% buffer for filesystem overhead
    local buffer_size=$((size_mb + size_mb * 30 / 100 + 100))
    echo "$buffer_size"
}

# Validate directory
validate_directory() {
    local dir="$1"
    
    if [ -z "$dir" ]; then
        echo -e "${RED}✗ No directory specified${NC}"
        return 1
    fi
    
    if [ ! -d "$dir" ]; then
        echo -e "${RED}✗ Directory does not exist: $dir${NC}"
        return 1
    fi
    
    # Check if directory is a system critical path
    local critical_paths=("/" "/bin" "/sbin" "/usr" "/lib" "/lib64" "/boot" "/dev" "/proc" "/sys")
    for critical in "${critical_paths[@]}"; do
        if [ "$dir" = "$critical" ]; then
            echo -e "${RED}✗ Cannot encrypt system critical directory: $dir${NC}"
            return 1
        fi
    done
    
    return 0
}

# Lock existing directory
lock_directory() {
    check_root
    
    local target_dir="$1"
    
    # Validate input
    if ! validate_directory "$target_dir"; then
        echo -e "${YELLOW}Usage: $0 lock <directory_path>${NC}"
        exit 1
    fi
    
    # Convert to absolute path
    target_dir=$(realpath "$target_dir")
    
    # Check if already locked
    if grep -q "^${target_dir}|" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Directory already encrypted!${NC}"
        echo -e "${CYAN}Status: 🔒 Locked${NC}"
        echo -e "${GREEN}To unlock: $0 unlock $target_dir${NC}"
        exit 0
    fi
    
    # Generate vault identifiers
    local vault_name=$(echo "$target_dir" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/^_//' | sed 's/_$//')
    local vault_file="$STORAGE_DIR/${vault_name}.vault"
    local mapper_name="lindlocker_${vault_name}"
    local temp_mount="/tmp/lindlocker_mount_$$"
    
    # Display header
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          🔒 LinDLocker - Directory Encryption Lock           ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Target Directory:${NC} ${GREEN}$target_dir${NC}"
    echo
    
    # Calculate size
    echo -e "${YELLOW}📊 Analyzing directory...${NC}"
    local dir_size=$(get_directory_size "$target_dir")
    local file_count=$(find "$target_dir" -type f 2>/dev/null | wc -l)
    local total_size=$(du -sh "$target_dir" 2>/dev/null | cut -f1)
    
    echo -e "${GREEN}  ✓ Files found: $file_count${NC}"
    echo -e "${GREEN}  ✓ Total size: $total_size${NC}"
    echo -e "${GREEN}  ✓ Container size: ${dir_size}MB (with buffer)${NC}"
    echo
    
    # Show security warning
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ⚠️  SECURITY WARNING                       ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}• Your password is THE ONLY way to access this data${NC}"
    echo -e "${YELLOW}• Lost password = Lost data PERMANENTLY${NC}"
    echo -e "${YELLOW}• Even root cannot recover data without password${NC}"
    echo -e "${YELLOW}• Military-grade LUKS encryption will be applied${NC}"
    echo
    echo -e "${CYAN}Directory will be encrypted: ${GREEN}$target_dir${NC}"
    echo
    read -p "$(echo -e ${YELLOW}Type 'YES' to continue:${NC} )" confirm
    
    if [ "$confirm" != "YES" ]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        exit 0
    fi
    
    log "Starting lock operation for: $target_dir"
    
    # Step 1: Create container
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[1/6] 📦 Creating encrypted container (${dir_size}MB)...${NC}"
    echo -e "${MAGENTA}⏳ Don't panic! This may take a moment for large directories${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    if command -v pv &> /dev/null; then
        dd if=/dev/zero bs=1M count="$dir_size" 2>/dev/null | pv -s "${dir_size}M" -p -t -e -r > "$vault_file"
    else
        dd if=/dev/zero of="$vault_file" bs=1M count="$dir_size" status=progress 2>&1 | grep -v records
    fi
    
    echo -e "${GREEN}  ✓ Container created successfully${NC}"
    log "Container created: $vault_file (${dir_size}MB)"
    
    # Step 2: LUKS format
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[2/6] 🔐 Setting up LUKS encryption...${NC}"
    echo -e "${MAGENTA}⏳ Initializing encryption... Please wait${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${GREEN}Enter a strong password (you'll need this to unlock):${NC}"
    
    if ! cryptsetup -q luksFormat "$vault_file"; then
        echo -e "${RED}✗ Encryption setup failed${NC}"
        rm -f "$vault_file"
        log "ERROR: LUKS format failed for $target_dir"
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ Encryption configured${NC}"
    log "LUKS encryption configured"
    
    # Step 3: Open container
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[3/6] 🔓 Opening encrypted container...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Enter the password you just set:${NC}"
    
    if ! cryptsetup open "$vault_file" "$mapper_name"; then
        echo -e "${RED}✗ Failed to open container${NC}"
        rm -f "$vault_file"
        log "ERROR: Failed to open container for $target_dir"
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ Container opened${NC}"
    
    # Step 4: Create filesystem
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[4/6] 💾 Creating filesystem...${NC}"
    echo -e "${MAGENTA}⏳ Formatting... Please be patient${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    mkfs.ext4 -q -F -L "lindlocker_$vault_name" "/dev/mapper/$mapper_name"
    echo -e "${GREEN}  ✓ Filesystem created${NC}"
    log "Filesystem created"
    
    # Step 5: Copy files
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[5/6] 📋 Moving files to encrypted storage...${NC}"
    echo -e "${MAGENTA}⏳ This is the slowest step - transferring $file_count files${NC}"
    echo -e "${MAGENTA}⏳ Progress will be shown below. DO NOT INTERRUPT!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    
    mkdir -p "$temp_mount"
    mount "/dev/mapper/$mapper_name" "$temp_mount"
    
    # Use rsync with progress
    rsync -aAXh --info=progress2 --no-i-r "$target_dir/" "$temp_mount/"
    
    echo
    echo -e "${GREEN}  ✓ Files transferred successfully${NC}"
    
    # Verify
    local orig_count=$(find "$target_dir" -type f 2>/dev/null | wc -l)
    local copy_count=$(find "$temp_mount" -type f 2>/dev/null | wc -l)
    
    echo -e "${CYAN}  📊 Verification:${NC}"
    echo -e "${GREEN}    • Source files: $orig_count${NC}"
    echo -e "${GREEN}    • Copied files: $copy_count${NC}"
    
    if [ "$orig_count" -ne "$copy_count" ]; then
        echo -e "${RED}  ✗ File count mismatch! Rolling back for safety${NC}"
        umount "$temp_mount"
        cryptsetup close "$mapper_name"
        rm -f "$vault_file"
        log "ERROR: File count mismatch during lock of $target_dir"
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ Verification passed${NC}"
    log "Files copied and verified: $file_count files"
    
    # Step 6: Finalize
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[6/6] 🔒 Finalizing encryption...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Unmount and close
    sync
    umount "$temp_mount"
    cryptsetup close "$mapper_name"
    rmdir "$temp_mount"
    
    # Backup and clear original
    local backup_dir="${target_dir}.lindlocker_backup_$$"
    mv "$target_dir" "$backup_dir"
    mkdir -p "$target_dir"
    rm -rf "$backup_dir"
    
    # Save configuration
    echo "$target_dir|$vault_file|$mapper_name" >> "$CONFIG_FILE"
    log "Lock completed successfully for: $target_dir"
    
    # Success message
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ✅ DIRECTORY LOCKED SUCCESSFULLY!                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📂 Directory:${NC} ${GREEN}$target_dir${NC}"
    echo -e "${CYAN}🔒 Status:${NC} ${RED}ENCRYPTED & LOCKED${NC}"
    echo -e "${CYAN}📊 Files protected:${NC} ${GREEN}$file_count${NC}"
    echo
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}What just happened:${NC}"
    echo -e "${GREEN}  ✓ All files encrypted with military-grade LUKS${NC}"
    echo -e "${GREEN}  ✓ Directory appears empty to everyone${NC}"
    echo -e "${GREEN}  ✓ Data inaccessible without password (even to root)${NC}"
    echo -e "${GREEN}  ✓ Original structure preserved inside encryption${NC}"
    echo
    echo -e "${CYAN}🔓 To access your files:${NC}"
    echo -e "${GREEN}   sudo $0 unlock $target_dir${NC}"
    echo
    echo -e "${RED}⚠️  CRITICAL: Password is the ONLY way to unlock!${NC}"
    echo
}

# Unlock directory
unlock_directory() {
    check_root
    
    local target_dir="$1"
    
    if [ -z "$target_dir" ]; then
        echo -e "${RED}✗ No directory specified${NC}"
        echo -e "${YELLOW}Usage: $0 unlock <directory_path>${NC}"
        exit 1
    fi
    
    target_dir=$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")
    
    # Get vault info
    local vault_info=$(grep "^${target_dir}|" "$CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$vault_info" ]; then
        echo -e "${RED}✗ Directory is not a locked vault: $target_dir${NC}"
        echo -e "${YELLOW}Use '$0 status' to see locked directories${NC}"
        exit 1
    fi
    
    IFS='|' read -r dir vault_file mapper_name <<< "$vault_info"
    
    # Check if already unlocked
    if mountpoint -q "$target_dir" 2>/dev/null; then
        echo -e "${GREEN}✓ Directory already unlocked!${NC}"
        echo -e "${CYAN}📂 Location: $target_dir${NC}"
        exit 0
    fi
    
    # Display header
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           🔓 LinDLocker - Unlocking Directory                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Directory:${NC} ${GREEN}$target_dir${NC}"
    echo
    echo -e "${YELLOW}Enter password to unlock:${NC}"
    
    log "Attempting unlock: $target_dir"
    
    # Open LUKS container
    if ! cryptsetup open "$vault_file" "$mapper_name"; then
        echo
        echo -e "${RED}✗ Failed to unlock! Incorrect password.${NC}"
        log "ERROR: Failed to unlock $target_dir - incorrect password"
        exit 1
    fi
    
    echo
    echo -e "${YELLOW}🔄 Mounting encrypted files...${NC}"
    
    # Ensure directory exists
    mkdir -p "$target_dir"
    
    # Mount
    if ! mount "/dev/mapper/$mapper_name" "$target_dir"; then
        echo -e "${RED}✗ Failed to mount${NC}"
        cryptsetup close "$mapper_name"
        log "ERROR: Failed to mount $target_dir"
        exit 1
    fi
    
    # Get stats
    local file_count=$(find "$target_dir" -type f 2>/dev/null | wc -l)
    local dir_size=$(du -sh "$target_dir" 2>/dev/null | cut -f1)
    
    log "Unlocked successfully: $target_dir"
    
    # Success message
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ✅ DIRECTORY UNLOCKED SUCCESSFULLY!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📂 Location:${NC} ${GREEN}$target_dir${NC}"
    echo -e "${CYAN}🔓 Status:${NC} ${GREEN}UNLOCKED & ACCESSIBLE${NC}"
    echo -e "${CYAN}📊 Files:${NC} ${GREEN}$file_count${NC}"
    echo -e "${CYAN}💾 Size:${NC} ${GREEN}$dir_size${NC}"
    echo
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Your files are now accessible!${NC}"
    echo
    echo -e "${CYAN}🔒 When finished, lock it again:${NC}"
    echo -e "${GREEN}   sudo $0 close $target_dir${NC}"
    echo
}

# Close (re-lock) directory
close_directory() {
    check_root
    
    local target_dir="$1"
    
    if [ -z "$target_dir" ]; then
        echo -e "${RED}✗ No directory specified${NC}"
        echo -e "${YELLOW}Usage: $0 close <directory_path>${NC}"
        exit 1
    fi
    
    target_dir=$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")
    
    # Get vault info
    local vault_info=$(grep "^${target_dir}|" "$CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$vault_info" ]; then
        echo -e "${RED}✗ Directory is not a locked vault${NC}"
        exit 1
    fi
    
    IFS='|' read -r dir vault_file mapper_name <<< "$vault_info"
    
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           🔒 LinDLocker - Closing Directory                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Directory:${NC} ${GREEN}$target_dir${NC}"
    echo
    
    # Check for open files
    if lsof "$target_dir" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Warning: Files are currently in use${NC}"
        echo
        lsof "$target_dir" 2>/dev/null | head -10
        echo
        read -p "$(echo -e ${YELLOW}Force close anyway? [y/N]:${NC} )" force
        if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
            echo -e "${YELLOW}Operation cancelled${NC}"
            exit 0
        fi
    fi
    
    log "Closing vault: $target_dir"
    
    # Unmount
    if mountpoint -q "$target_dir" 2>/dev/null; then
        echo -e "${YELLOW}🔄 Unmounting directory...${NC}"
        sync
        if ! umount "$target_dir" 2>/dev/null; then
            echo -e "${YELLOW}  ⚠️  Forcing unmount...${NC}"
            umount -l "$target_dir"
        fi
        echo -e "${GREEN}  ✓ Unmounted${NC}"
    fi
    
    # Close LUKS
    if [ -e "/dev/mapper/$mapper_name" ]; then
        echo -e "${YELLOW}🔐 Closing encrypted container...${NC}"
        cryptsetup close "$mapper_name"
        echo -e "${GREEN}  ✓ Container closed${NC}"
    fi
    
    log "Closed successfully: $target_dir"
    
    # Success message
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║             ✅ DIRECTORY LOCKED SUCCESSFULLY!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📂 Directory:${NC} ${GREEN}$target_dir${NC}"
    echo -e "${CYAN}🔒 Status:${NC} ${RED}ENCRYPTED & LOCKED${NC}"
    echo
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Files are now encrypted and inaccessible${NC}"
    echo -e "${GREEN}✓ Directory appears empty to everyone (including root)${NC}"
    echo
    echo -e "${CYAN}🔓 To access again:${NC}"
    echo -e "${GREEN}   sudo $0 unlock $target_dir${NC}"
    echo
}

# REMOVE ENCRYPTION - Decrypt completely and return to normal
remove_encryption() {
    check_root
    
    local target_dir="$1"
    
    if [ -z "$target_dir" ]; then
        echo -e "${RED}✗ No directory specified${NC}"
        echo -e "${YELLOW}Usage: $0 remove <directory_path>${NC}"
        exit 1
    fi
    
    target_dir=$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")
    
    # Get vault info
    local vault_info=$(grep "^${target_dir}|" "$CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$vault_info" ]; then
        echo -e "${RED}✗ Directory is not a locked vault${NC}"
        exit 1
    fi
    
    IFS='|' read -r dir vault_file mapper_name <<< "$vault_info"
    
    # Display warning
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║        🗑️  REMOVE ENCRYPTION - RETURN TO NORMAL              ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Directory:${NC} ${GREEN}$target_dir${NC}"
    echo
    echo -e "${YELLOW}This will:${NC}"
    echo -e "${GREEN}  ✓ Decrypt all files${NC}"
    echo -e "${GREEN}  ✓ Restore directory to normal (unencrypted) state${NC}"
    echo -e "${GREEN}  ✓ Delete the encrypted container${NC}"
    echo -e "${GREEN}  ✓ Files will remain accessible normally${NC}"
    echo
    echo -e "${RED}After this, the directory will NO LONGER be protected!${NC}"
    echo
    read -p "$(echo -e ${YELLOW}Type 'REMOVE' to confirm:${NC} )" confirm
    
    if [ "$confirm" != "REMOVE" ]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        exit 0
    fi
    
    log "Removing encryption from: $target_dir"
    
    local temp_mount="/tmp/lindlocker_remove_$$"
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[1/5] 🔓 Opening encrypted container...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Enter password to decrypt:${NC}"
    
    if ! cryptsetup open "$vault_file" "$mapper_name"; then
        echo -e "${RED}✗ Failed to open. Incorrect password?${NC}"
        log "ERROR: Failed to open for removal - $target_dir"
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ Container opened${NC}"
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[2/5] 📋 Extracting encrypted files...${NC}"
    echo -e "${MAGENTA}⏳ Decrypting and copying files back...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    
    mkdir -p "$temp_mount"
    mount "/dev/mapper/$mapper_name" "$temp_mount"
    
    # Get file count
    local file_count=$(find "$temp_mount" -type f 2>/dev/null | wc -l)
    echo -e "${CYAN}  📊 Decrypting $file_count files...${NC}"
    echo
    
    # Backup current directory if not empty
    local backup_dir="${target_dir}.backup_$$"
    if [ "$(ls -A $target_dir 2>/dev/null)" ]; then
        mv "$target_dir" "$backup_dir"
    fi
    
    mkdir -p "$target_dir"
    
    # Copy files with progress
    rsync -aAXh --info=progress2 --no-i-r "$temp_mount/" "$target_dir/"
    
    echo
    echo -e "${GREEN}  ✓ Files extracted${NC}"
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[3/5] 🔒 Closing encrypted container...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    sync
    umount "$temp_mount"
    cryptsetup close "$mapper_name"
    rmdir "$temp_mount"
    
    echo -e "${GREEN}  ✓ Container closed${NC}"
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[4/5] 🗑️  Deleting encrypted container...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    rm -f "$vault_file"
    echo -e "${GREEN}  ✓ Container deleted${NC}"
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[5/5] 📝 Updating configuration...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Remove from config
    sed -i "\|^${target_dir}||d" "$CONFIG_FILE"
    
    # Remove backup if exists
    [ -d "$backup_dir" ] && rm -rf "$backup_dir"
    
    echo -e "${GREEN}  ✓ Configuration updated${NC}"
    
    log "Encryption removed successfully: $target_dir"
    
    # Success message
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        ✅ ENCRYPTION REMOVED SUCCESSFULLY!                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📂 Directory:${NC} ${GREEN}$target_dir${NC}"
    echo -e "${CYAN}🔓 Status:${NC} ${GREEN}NORMAL (Unencrypted)${NC}"
    echo -e "${CYAN}📊 Files restored:${NC} ${GREEN}$file_count${NC}"
    echo
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ All files decrypted and restored${NC}"
    echo -e "${GREEN}✓ Directory is now normal (no encryption)${NC}"
    echo -e "${GREEN}✓ Encrypted container deleted${NC}"
    echo
    echo -e "${CYAN}Your files are now accessible normally without password${NC}"
    echo
}

# Show status
show_status() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            LinDLocker - Encrypted Directories                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}No encrypted directories found${NC}"
        echo
        echo -e "${CYAN}Lock a directory:${NC}"
        echo -e "${GREEN}  sudo $0 lock /path/to/directory${NC}"
        echo
        echo -e "${CYAN}Example:${NC}"
        echo -e "${GREEN}  sudo $0 lock /root/.ssh${NC}"
        return
    fi
    
    printf "${CYAN}%-50s %-20s${NC}\n" "DIRECTORY" "STATUS"
    echo "────────────────────────────────────────────────────────────────────"
    
    while IFS='|' read -r dir vault_file mapper_name; do
        local status="🔒 LOCKED"
        local color=$RED
        
        if mountpoint -q "$dir" 2>/dev/null; then
            status="🔓 UNLOCKED"
            color=$GREEN
        fi
        
        echo -e "${color}$(printf "%-50s %-20s" "$dir" "$status")${NC}"
    done < "$CONFIG_FILE"
    
    echo
    echo -e "${CYAN}Commands:${NC}"
    echo -e "${GREEN}  Unlock:  sudo $0 unlock <directory>${NC}"
    echo -e "${GREEN}  Close:   sudo $0 close <directory>${NC}"
    echo -e "${GREEN}  Remove:  sudo $0 remove <directory>${NC}"
    echo
}

# Change password
change_password() {
    check_root
    
    local target_dir="$1"
    
    if [ -z "$target_dir" ]; then
        echo -e "${RED}✗ No directory specified${NC}"
        echo -e "${YELLOW}Usage: $0 change-password <directory_path>${NC}"
        exit 1
    fi
    
    target_dir=$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")
    
    local vault_info=$(grep "^${target_dir}|" "$CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$vault_info" ]; then
        echo -e "${RED}✗ Directory is not a locked vault${NC}"
        exit 1
    fi
    
    IFS='|' read -r dir vault_file mapper_name <<< "$vault_info"
    
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              🔑 Change Directory Password                     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Directory:${NC} ${GREEN}$target_dir${NC}"
    echo
    echo -e "${YELLOW}You will need the current password, then set a new one${NC}"
    echo
    
    log "Password change attempt: $target_dir"
    
    if cryptsetup luksChangeKey "$vault_file"; then
        echo
        echo -e "${GREEN}✅ Password changed successfully!${NC}"
        echo -e "${YELLOW}Remember your new password - it's the only way to unlock${NC}"
        log "Password changed: $target_dir"
    else
        echo
        echo -e "${RED}✗ Failed to change password${NC}"
        log "ERROR: Password change failed - $target_dir"
        exit 1
    fi
}

# Show recovery info
show_recovery() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           🆘 EMERGENCY RECOVERY INSTRUCTIONS                  ║${NC}"
    echo -e "${BLUE}║        Access Your Data Without This Script                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}If the LinDLocker script is deleted, you can STILL access your data!${NC}"
    echo
    echo -e "${GREEN}Your encrypted data is stored in:${NC}"
    echo -e "${CYAN}  • Containers: /var/lib/lindlocker/containers/${NC}"
    echo -e "${CYAN}  • Config: /var/lib/lindlocker/vaults.conf${NC}"
    echo
    echo -e "${GREEN}MANUAL UNLOCK COMMANDS:${NC}"
    echo
    echo -e "${YELLOW}1. Find your encrypted container:${NC}"
    echo -e "${CYAN}   ls -lh /var/lib/lindlocker/containers/${NC}"
    echo
    echo -e "${YELLOW}2. Open the encrypted container:${NC}"
    echo -e "${CYAN}   sudo cryptsetup open /var/lib/lindlocker/containers/VAULT.vault my_vault${NC}"
    echo -e "${CYAN}   (Enter your password)${NC}"
    echo
    echo -e "${YELLOW}3. Mount to access files:${NC}"
    echo -e "${CYAN}   sudo mkdir -p /mnt/recovery${NC}"
    echo -e "${CYAN}   sudo mount /dev/mapper/my_vault /mnt/recovery${NC}"
    echo
    echo -e "${YELLOW}4. Access your files:${NC}"
    echo -e "${CYAN}   cd /mnt/recovery${NC}"
    echo
    echo -e "${GREEN}MANUAL LOCK COMMANDS:${NC}"
    echo
    echo -e "${CYAN}   sudo umount /mnt/recovery${NC}"
    echo -e "${CYAN}   sudo cryptsetup close my_vault${NC}"
    echo
    echo -e "${GREEN}VIEW YOUR LOCKED DIRECTORIES:${NC}"
    echo -e "${CYAN}   cat /var/lib/lindlocker/vaults.conf${NC}"
    echo
    echo -e "${RED}IMPORTANT:${NC}"
    echo -e "${YELLOW}  • Your password is in the LUKS container (not the script)${NC}"
    echo -e "${YELLOW}  • Even without the script, your password works${NC}"
    echo -e "${YELLOW}  • The script is just a convenient wrapper${NC}"
    echo
}

# Export recovery info
export_info() {
    local output_file="$1"
    
    if [ -z "$output_file" ]; then
        output_file="$HOME/lindlocker_recovery_$(date +%Y%m%d_%H%M%S).txt"
    fi
    
    echo -e "${YELLOW}Exporting recovery information...${NC}"
    
    {
        echo "LinDLocker Recovery Information"
        echo "Generated: $(date)"
        echo "================================="
        echo
        echo "ENCRYPTED DIRECTORIES:"
        echo
        
        if [ -s "$CONFIG_FILE" ]; then
            while IFS='|' read -r dir vault_file mapper_name; do
                echo "Directory: $dir"
                echo "  Container: $vault_file"
                echo "  Mapper: $mapper_name"
                echo
                echo "  Unlock commands:"
                echo "    sudo cryptsetup open $vault_file $mapper_name"
                echo "    sudo mount /dev/mapper/$mapper_name $dir"
                echo
                echo "  Lock commands:"
                echo "    sudo umount $dir"
                echo "    sudo cryptsetup close $mapper_name"
                echo
                echo "──────────────────────────────────────"
                echo
            done < "$CONFIG_FILE"
        fi
        
        echo "GENERAL RECOVERY:"
        echo "  Containers: /var/lib/lindlocker/containers/"
        echo "  Config: /var/lib/lindlocker/vaults.conf"
        echo
    } > "$output_file"
    
    chmod 600 "$output_file"
    
    echo -e "${GREEN}✓ Recovery info exported to: $output_file${NC}"
    echo -e "${YELLOW}Keep this file safe!${NC}"
}

# Show help
show_help() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     🔒 LinDLocker v${VERSION} - Directory Encryption Tool          ║${NC}"
    echo -e "${BLUE}║         Military-Grade LUKS Encryption • Root-Proof          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}USAGE:${NC}"
    echo "  sudo $0 <command> <directory>"
    echo
    echo -e "${GREEN}MAIN COMMANDS:${NC}"
    echo -e "${CYAN}  lock <dir>           ${NC} Encrypt and lock existing directory"
    echo -e "${CYAN}  unlock <dir>         ${NC} Unlock and access files"
    echo -e "${CYAN}  close <dir>          ${NC} Re-lock directory (same password)"
    echo -e "${CYAN}  remove <dir>         ${NC} Remove encryption completely (back to normal)"
    echo -e "${CYAN}  status               ${NC} Show all encrypted directories"
    echo
    echo -e "${GREEN}MANAGEMENT:${NC}"
    echo -e "${CYAN}  change-password <dir>${NC} Change directory password"
    echo -e "${CYAN}  recovery             ${NC} Show emergency recovery instructions"
    echo -e "${CYAN}  export [file]        ${NC} Export recovery info to file"
    echo -e "${CYAN}  version              ${NC} Show version"
    echo -e "${CYAN}  help                 ${NC} Show this help"
    echo
    echo -e "${GREEN}EXAMPLES:${NC}"
    echo
    echo -e "${YELLOW}  # Lock SSH keys${NC}"
    echo -e "${CYAN}  sudo $0 lock /root/.ssh${NC}"
    echo
    echo -e "${YELLOW}  # Unlock when needed${NC}"
    echo -e "${CYAN}  sudo $0 unlock /root/.ssh${NC}"
    echo
    echo -e "${YELLOW}  # Close when done${NC}"
    echo -e "${CYAN}  sudo $0 close /root/.ssh${NC}"
    echo
    echo -e "${YELLOW}  # Remove encryption completely${NC}"
    echo -e "${CYAN}  sudo $0 remove /root/.ssh${NC}"
    echo
    echo -e "${YELLOW}  # Check status${NC}"
    echo -e "${CYAN}  sudo $0 status${NC}"
    echo
    echo -e "${GREEN}HOW IT WORKS:${NC}"
    echo "  1. Takes your EXISTING directory with files"
    echo "  2. Creates encrypted LUKS container (auto-sized)"
    echo "  3. Moves files into encrypted storage"
    echo "  4. Directory appears empty when locked"
    echo "  5. Files accessible only with password when unlocked"
    echo
    echo -e "${GREEN}SECURITY:${NC}"
    echo "  • Military-grade LUKS encryption (AES-256)"
    echo "  • Password is THE ONLY way to access files"
    echo "  • No backdoors, no recovery without password"
    echo "  • Even root cannot bypass encryption"
    echo "  • All permissions and attributes preserved"
    echo
    echo -e "${RED}⚠ IMPORTANT:${NC}"
    echo "  • Lost password = Lost data FOREVER"
    echo "  • Use strong, unique passwords"
    echo "  • Keep locked when not in use"
    echo
    echo -e "${GREEN}DATA SAFETY:${NC}"
    echo "  • Data stored in: /var/lib/lindlocker/"
    echo "  • Safe even if script deleted"
    echo "  • Use 'recovery' command for manual access"
    echo "  • Use 'export' to save recovery info"
    echo
}

# Show version
show_version() {
    echo -e "${BLUE}LinDLocker v${VERSION}${NC}"
    echo "Military-grade directory encryption for Linux"
    echo
}

# Main
main() {
    check_dependencies
    init_vault_dir
    
    local command="${1:-help}"
    local target="${2:-}"
    
    case "$command" in
        lock|encrypt)
            lock_directory "$target"
            ;;
        unlock|open)
            unlock_directory "$target"
            ;;
        close|relock)
            close_directory "$target"
            ;;
        remove|decrypt|delete)
            remove_encryption "$target"
            ;;
        status|list)
            show_status
            ;;
        change-password|passwd)
            change_password "$target"
            ;;
        recovery|recover)
            show_recovery
            ;;
        export|backup)
            export_info "$target"
            ;;
        version|--version|-v)
            show_version
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}✗ Unknown command: $command${NC}"
            echo
            show_help
            exit 1
            ;;
    esac
}

main "$@"