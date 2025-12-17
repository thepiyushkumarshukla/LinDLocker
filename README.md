# 🔒 LinDLocker ( Linux Directory Locker )

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

Step 2: Install Dependencies
bash

sudo ./setup.sh

Step 3: Make Script Executable
bash

chmod +x lindlocker.sh

🎯 Quick Start
Lock your first directory:
bash

sudo ./lindlocker.sh lock /home/user/secret-files

Unlock when needed:
bash

sudo ./lindlocker.sh unlock /home/user/secret-files

Lock it back:
bash

sudo ./lindlocker.sh close /home/user/secret-files

📖 Complete Command Reference
Main Commands:
Command	Description	Example
lock <dir>	Encrypt and lock directory	sudo ./lindlocker.sh lock /root/.ssh
unlock <dir>	Unlock and access files	sudo ./lindlocker.sh unlock /root/.ssh
close <dir>	Re-lock directory	sudo ./lindlocker.sh close /root/.ssh
remove <dir>	Remove encryption completely	sudo ./lindlocker.sh remove /root/.ssh
status	Show all encrypted directories	sudo ./lindlocker.sh status
Management Commands:
Command	Description	Example
change-password <dir>	Change directory password	sudo ./lindlocker.sh change-password /root/.ssh
recovery	Show emergency recovery instructions	sudo ./lindlocker.sh recovery
export [file]	Export recovery info	sudo ./lindlocker.sh export ~/recovery.txt
help	Show help message	sudo ./lindlocker.sh help
version	Show version	sudo ./lindlocker.sh version
🛡️ Security Features
What Makes LinDLocker Secure?

    LUKS Encryption: Uses Linux Unified Key Setup with AES-256

    No Backdoors: Password is the ONLY way to access data

    Root Protection: Even system administrators with root access cannot decrypt without password

    Stealth Mode: Locked directories appear as empty folders

    No Metadata Leaks: File names, sizes, and permissions are encrypted

⚠️ Critical Security Warning:

    Lost password = Lost data forever

    No recovery possible without password

    No master key or backdoor exists

    Always test with non-critical data first

🆘 Emergency Recovery
What if the script is deleted?

Your data is SAFE! The encryption containers are stored separately. Here's how to recover:
Manual Recovery Commands:

    Find your encrypted container:
    bash

ls -lh /var/lib/lindlocker/containers/

Open the container:
bash

sudo cryptsetup open /var/lib/lindlocker/containers/YOUR_VAULT.vault my_vault

Mount to access files:
bash

sudo mkdir -p /mnt/recovery
sudo mount /dev/mapper/my_vault /mnt/recovery
cd /mnt/recovery

When done, close it:
bash

sudo umount /mnt/recovery
sudo cryptsetup close my_vault

View All Locked Directories:
bash

cat /var/lib/lindlocker/vaults.conf

Export Recovery Information:
bash

sudo ./lindlocker.sh export ~/lindlocker-backup.txt

📁 How It Works
The Encryption Process:

    Analysis: Scans directory to calculate required size

    Container Creation: Creates encrypted LUKS container

    File Transfer: Moves all files into encrypted storage

    Cleanup: Securely removes original files

    Stealth: Directory appears empty when locked

Data Storage Locations:

    Containers: /var/lib/lindlocker/containers/

    Configuration: /var/lib/lindlocker/vaults.conf

    Logs: /var/lib/lindlocker/lindlocker.log

🚫 What NOT To Encrypt

DO NOT encrypt these directories:

    / (root filesystem)

    /bin, /sbin, /usr

    /lib, /lib64

    /boot, /dev

    /proc, /sys

Safe directories to encrypt:

    /home/user/documents/

    /root/.ssh/

    /var/www/private/

    Any user data directories

🔧 Technical Details
Dependencies:

    cryptsetup - LUKS encryption

    rsync - File transfer with attributes

    pv - Progress visualization

    lsof - Open file detection

Supported Distributions:

    Ubuntu/Debian

    RHEL/CentOS

    Fedora

    Arch Linux

    openSUSE

Filesystem Compatibility:

    Ext4 (primary)

    XFS, Btrfs (should work)

    Any filesystem supported by LUKS

❓ Frequently Asked Questions
Q: Can I recover data if I forget the password?

A: NO! The password is the only key. There is no recovery mechanism.
Q: Does encryption work across reboots?

A: YES! Directories remain encrypted after reboot.
Q: Can I encrypt multiple directories?

A: YES! Each directory gets its own encrypted container.
Q: What's the performance impact?

A: Minimal. Modern CPUs have AES-NI hardware acceleration.
Q: Can I move encrypted containers?

A: YES! Containers are portable across Linux systems.
🐛 Troubleshooting
Common Issues:

    "Directory does not exist"

        Check path spelling

        Use absolute paths: /home/user/docs not ~/docs

    "Missing dependencies"

        Run: sudo ./setup.sh

        Or manually install packages

    "Permission denied"

        Always use sudo

        Ensure you have root privileges

    "File count mismatch"

        Files were modified during encryption

        Try again when system is idle

View Logs:
bash

sudo cat /var/lib/lindlocker/lindlocker.log

📜 License

MIT License - See LICENSE file for details.
⭐ Support

Found this useful? Give it a star on GitHub!
🚨 Disclaimer

USE AT YOUR OWN RISK! The developers are not responsible for data loss. Always:

    Test with non-critical data first

    Keep backups of important files

    Remember your passwords

LinDLocker - Because your privacy matters, even from root.
text


## How to Use:

1. **Save the files:**
   - Save the first script as `setup.sh`
   - Save the second content as `README.md`

2. **Make them executable:**
   ```bash
   chmod +x setup.sh
   chmod +x lindlocker.sh

Test the setup:
bash

sudo ./setup.sh
sudo ./lindlocker.sh help