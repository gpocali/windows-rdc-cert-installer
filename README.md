# Auto-Update RDP Certificate with Let's Encrypt

## Overview

This repository contains a fully autonomous PowerShell script designed to securely fetch Let's Encrypt SSL certificates from a remote server (e.g., a Linux host running Certbot), convert them locally, and apply them to the native Windows Remote Desktop Protocol (RDP) service.

By automating the retrieval and installation of SSL certificates, this script ensures your RDP connections remain securely encrypted without the hassle of manual certificate generation and binding every 90 days.

## Features

- **Zero-Touch Automation:** Uses SSH private key authentication and automatically handles host key verification for completely hands-off execution.
- **Native Tools Only:** Relies entirely on built-in Windows OpenSSH (`scp.exe`) and `certutil.exe`. No third-party binaries (like OpenSSL) are required on the Windows host.
- **Secure by Design:**
  - Generates a cryptographically secure, random 20-character password entirely in memory for the PFX conversion process.
  - Leaves no hardcoded passwords in the script.
  - Securely deletes all temporary key files and `.pfx` files after the import process completes.
- **Seamless RDP Integration:** Automatically queries WMI, binds the new certificate's SHA1 thumbprint to the `RDP-tcp` listener, and restarts the Terminal Service to apply changes immediately.

## Prerequisites

1. **Windows OS:** Windows 10, Windows 11, or Windows Server with PowerShell 5.1 or later.
2. **OpenSSH Client:** The native Windows OpenSSH Client must be installed (enabled by default on modern Windows 11 builds).
3. **SSH Access:**
   - A remote server hosting the Let's Encrypt certificates (`fullchain.pem` and `privkey.pem`).
   - SSH access to the remote server using an **SSH Private Key**.
4. **Administrator Privileges:** The script must be run as Administrator to access the Local Machine Certificate Store and restart system services.

## Configuration

Before running the script, open it in your preferred editor and update the **Configuration Variables** section:

```powershell
# SSH Settings
$SshUser       = "root"                                # Your SSH username
$SshHost       = "192.168.1.50"                        # Remote server IP or FQDN
$SshKeyPath    = "C:\path\to\your\private_key.pem"     # Path to your private SSH key on the Windows machine

# Remote Certificate Paths (Default Certbot paths shown)
$RemoteCertPem = "/etc/letsencrypt/live/yourdomain.com/fullchain.pem"
$RemoteKeyPem  = "/etc/letsencrypt/live/yourdomain.com/privkey.pem"
```

## Usage

Run the script from an **Elevated PowerShell** prompt (Run as Administrator):

```powershell
.\Update-RDPCertificate.ps1
```

## Automating with Windows Task Scheduler

Since Let's Encrypt certificates expire every 90 days, it is highly recommended to run this script automatically using Windows Task Scheduler.

1. Open **Task Scheduler** (`taskschd.msc`).
2. Click **Create Task**.
3. **General Tab:**
   - Name it (e.g., "Update RDP SSL Certificate").
   - Select **Run whether user is logged on or not**.
   - Check **Run with highest privileges** (CRITICAL).
4. **Triggers Tab:**
   - Create a new trigger to run **Monthly** (or every 60 days to align with Let's Encrypt renewals).
5. **Actions Tab:**
   - Action: **Start a program**
   - Program/script: `powershell.exe`
   - Add arguments: `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\to\your\Update-RDPCertificate.ps1"`
6. Save the task.

## Security Notes: SSH Key Permissions

Windows OpenSSH is strict regarding file permissions for private keys. If your key has permissive access rights, SSH will ignore the key and the script will fail.

Ensure the private key file defined in `$SshKeyPath` is locked down:
1. Right-click the `.pem` or `.id_rsa` file > **Properties** > **Security** > **Advanced**.
2. Click **Disable inheritance** and remove all inherited permissions.
3. Add **Read** access *only* for the specific user account running the script (or the `SYSTEM` account if running via Task Scheduler).

## Troubleshooting

- **"Failed to download files"**: Check your SSH key path, permissions, and network connectivity. Ensure the user specified has read access to the `.pem` files on the remote Linux host.
- **"certutil failed to merge"**: Certutil requires both files to be named exactly the same (e.g., `cert.cer` and `cert.key`) in the same directory. The script handles this renaming automatically, but ensure your system's temp folder isn't blocking execution due to aggressive antivirus policies.
- **Certificate not applying**: Ensure you ran the script from an elevated administrative PowerShell window.