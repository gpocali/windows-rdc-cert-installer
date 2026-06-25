<#
.SYNOPSIS
Downloads Let's Encrypt PEM files autonomously via SSH, securely converts them to PFX locally, 
and configures Windows 11 RDP to use the new certificate.

.DESCRIPTION
This script is fully self-contained. It uses a defined SSH private key and bypasses 
the strict host key checking prompt to ensure zero manual intervention is required. 
It generates a secure password in memory, merges the files into a PFX, imports it, 
binds it to RDP, and cleans up all temporary data.
#>

# ==========================================
# 1. Configuration Variables
# ==========================================

# SSH Settings
$SshUser       = "root"
$SshHost       = "192.168.1.50" # Or FQDN
$SshKeyPath    = "C:\path\to\your\private_key.pem" # Path to your private key file

# Remote Certificate Paths
$RemoteCertPem = "/etc/letsencrypt/live/yourdomain.com/fullchain.pem"
$RemoteKeyPem  = "/etc/letsencrypt/live/yourdomain.com/privkey.pem"

# Local Temp Paths
$TempDir       = "$env:TEMP\rdp_cert_update"
$LocalCer      = "$TempDir\cert.cer"
$LocalKey      = "$TempDir\cert.key"
$LocalPfx      = "$TempDir\cert.pfx"

# ==========================================
# 2. Generate Random Secure Password
# ==========================================
Write-Host "Generating a random secure password for PFX conversion..." -ForegroundColor Cyan

$length  = 20
$charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$'
$rng     = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes   = New-Object byte[]($length)
$rng.GetBytes($bytes)

$RandomPassword = -join ($bytes | ForEach-Object { $charSet[$_ % $charSet.Length] })
$rng.Dispose()

$SecurePassword = ConvertTo-SecureString -String $RandomPassword -AsPlainText -Force
Write-Host "Password generated securely in memory." -ForegroundColor Green

# ==========================================
# 3. Setup Temp Folder & Download PEM files
# ==========================================
if (-Not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir | Out-Null }

Write-Host "Downloading Let's Encrypt files autonomously via SCP..." -ForegroundColor Cyan

# Define the SSH options to use the key and ignore host checking prompts
$SshOptions = @(
    "-i", $SshKeyPath,
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=NUL"
)

# Download the public cert
& scp.exe $SshOptions "$SshUser@$SshHost`:$RemoteCertPem" $LocalCer
# Download the private key 
& scp.exe $SshOptions "$SshUser@$SshHost`:$RemoteKeyPem" $LocalKey

if (-Not (Test-Path $LocalCer) -or -Not (Test-Path $LocalKey)) {
    Write-Host "Error: Failed to download files. Check your SSH key path, permissions, and network access." -ForegroundColor Red
    exit
}

# ==========================================
# 4. Convert PEM + KEY to PFX using certutil
# ==========================================
Write-Host "Merging PEM and private key into PFX format..." -ForegroundColor Cyan

& certutil.exe -MergePfx -p "$RandomPassword" "$LocalCer" "$LocalPfx" | Out-Null

if (-Not (Test-Path $LocalPfx)) {
    Write-Host "Error: certutil failed to merge the files into a PFX." -ForegroundColor Red
    exit
}
Write-Host "PFX generated successfully." -ForegroundColor Green

# ==========================================
# 5. Import the Certificate
# ==========================================
Write-Host "Importing PFX into the Local Machine store..." -ForegroundColor Cyan

$Cert = Import-PfxCertificate -FilePath $LocalPfx -CertStoreLocation Cert:\LocalMachine\My -Password $SecurePassword

if (-Not $Cert) {
    Write-Host "Error: Failed to import the PFX." -ForegroundColor Red
    exit
}

$Thumbprint = $Cert.Thumbprint
Write-Host "Certificate imported! Thumbprint: $Thumbprint" -ForegroundColor Green

# ==========================================
# 6. Configure RDP to Use the New Certificate
# ==========================================
Write-Host "Binding certificate to the Remote Desktop service..." -ForegroundColor Cyan

$WmiPath = (Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").__path
Set-WmiInstance -Path $WmiPath -Arguments @{SSLCertificateSHA1Hash="$Thumbprint"} | Out-Null

# ==========================================
# 7. Cleanup and Restart Service
# ==========================================
Write-Host "Cleaning up local temporary files and purging passwords..." -ForegroundColor Cyan

Remove-Item -Path $TempDir -Recurse -Force
$RandomPassword = $null

Write-Host "Restarting Remote Desktop Services to apply changes..." -ForegroundColor Cyan
Restart-Service -Name "TermService" -Force

Write-Host "Done! Windows 11 RDP is now autonomously updated with the Let's Encrypt certificate." -ForegroundColor Green