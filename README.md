# 🔒 LinDLocker ( Linux Directory Locker )

![lindlocker](https://raw.githubusercontent.com/thepiyushkumarshukla/LinDLocker/refs/heads/main/lindlocker.png)

**Requires:** Root access, Linux kernel with LUKS support

## 🚀 What is LinDLocker?

LinDLocker is a powerful bash script that encrypts existing directories with military-grade LUKS encryption. When locked, directories appear empty to everyone - even root users. Only with the correct password can the contents be accessed.

### Key Features:
- 🔐 **Military-grade LUKS encryption** (AES-256)
- 👻 **Stealth mode** - Locked directories appear empty
- 🛡️ **Root-proof** - Even system administrators can't bypass encryption
- 📊 **Automatic sizing** - Calculates optimal container size
- 🔄 **Preserves permissions** - All file attributes maintained
- 🚨 **Emergency recovery** - Access data even without the script

## 📦 Installation

### Step 1: Download the Script
```bash
git clone https://github.com/yourusername/lindlocker.git

cd lindlocker
```

### Step 2: Install Dependencies
```bash
sudo ./setup.sh
```

### Step 3: Make Script Executable
```bash
chmod +x lindlocker
```

## 🎯 Quick Start
Lock your first directory:
```bash
sudo ./lindlocker lock /home/user/secret-files
```
Unlock when needed:
```bash

sudo ./lindlocker unlock /home/user/secret-files
```
Lock it back:
```bash

sudo ./lindlocker close /home/user/secret-files
```
Remove the Lock:
```bash
sudo ./lindlocker remove /home/user/secret-files
```

# 🛡️ Security Features

## What Makes LinDLocker Secure?
- **LUKS Encryption**: Uses Linux Unified Key Setup with AES-256
- **No Backdoors**: Password is the ONLY way to access data
- **Root Protection**: Even system administrators with root access cannot decrypt without password
- **Stealth Mode**: Locked directories appear as empty folders
- **No Metadata Leaks**: File names, sizes, and permissions are encrypted

## ⚠️ Critical Security Warning:
- **Lost password = Lost data forever**
- No recovery possible without password
- No master key or backdoor exists
- Always test with non-critical data first

# 🆘 Emergency Recovery

## What if the script is deleted?
Your data is SAFE! The encryption containers are stored separately. Here's how to recover:

## Manual Recovery Commands:

1. **Find your encrypted container:**
   ```bash
   ls -lh /var/lib/lindlocker/containers/
   ```

2. **Open the container:**
   ```bash
   sudo cryptsetup open /var/lib/lindlocker/containers/YOUR_VAULT.vault my_vault
   ```

3. **Mount to access files:**
   ```bash
   sudo mkdir -p /mnt/recovery
   sudo mount /dev/mapper/my_vault /mnt/recovery
   cd /mnt/recovery
   ```

4. **When done, close it:**
   ```bash
   sudo umount /mnt/recovery
   sudo cryptsetup close my_vault
   ```

## View All Locked Directories:
```bash
cat /var/lib/lindlocker/vaults.conf
```

## Export Recovery Information:
```bash
sudo ./lindlocker export ~/lindlocker-backup.txt
```

# 📁 How It Works

## The Encryption Process:
1. **Analysis**: Scans directory to calculate required size
2. **Container Creation**: Creates encrypted LUKS container
3. **File Transfer**: Moves all files into encrypted storage
4. **Cleanup**: Securely removes original files
5. **Stealth**: Directory appears empty when locked

## Data Storage Locations:
- **Containers**: `/var/lib/lindlocker/containers/`
- **Configuration**: `/var/lib/lindlocker/vaults.conf`
- **Logs**: `/var/lib/lindlocker/lindlocker.log`

# 🚫 What NOT To Encrypt

## DO NOT encrypt these directories:
- `/` (root filesystem)
- `/bin`, `/sbin`, `/usr`
- `/lib`, `/lib64`
- `/boot`, `/dev`
- `/proc`, `/sys`

## Safe directories to encrypt:
- `/home/user/documents/`
- `/root/.ssh/`
- `/var/www/private/`
- Any user data directories

# 🔧 Technical Details

## Dependencies:
- `cryptsetup` - LUKS encryption
- `rsync` - File transfer with attributes
- `pv` - Progress visualization
- `lsof` - Open file detection

## Supported Distributions:
- Ubuntu/Debian
- RHEL/CentOS
- Fedora
- Arch Linux
- openSUSE

Mail on :- **piyushbusiness29@gmail.com** in case of any Bug or Query !