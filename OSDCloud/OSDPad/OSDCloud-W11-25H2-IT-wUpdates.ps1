<#
.SYNOPSIS
    OSDCloud Automation Script for Windows Deployment

.DESCRIPTION
    Automates the deployment of Windows 11 with specified parameters, downloads OOBE scripts, and sets up post-installation tasks.

.NOTES
    Author: ITAE
    Version: 1.0

    Changelog:
    - 2025-10-16: 1.0 Initial version

    
#>



# Script di installazione manuale - bypassa Start-OSDCloud

Write-Host "Starting Custom Windows Installation..." -ForegroundColor Cyan

# 1. Prepara il disco
Write-Host "Preparing disk..." -ForegroundColor Yellow
$Disk = Get-Disk | Where-Object {$_.BusType -ne 'USB'} | Select-Object -First 1
Clear-Disk -Number $Disk.Number -RemoveData -Confirm:$false -ErrorAction SilentlyContinue

Initialize-Disk -Number $Disk.Number -PartitionStyle GPT

# Crea partizioni
$EFI = New-Partition -DiskNumber $Disk.Number -Size 100MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
$MSR = New-Partition -DiskNumber $Disk.Number -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
$Windows = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

# Formatta partizioni
Format-Volume -Partition $EFI -FileSystem FAT32 -NewFileSystemLabel "System" -Confirm:$false
$Windows | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false

# Assegna lettere drive
$EFI | Set-Partition -NewDriveLetter S
$Windows | Set-Partition -NewDriveLetter W

Write-Host "Disk prepared successfully!" -ForegroundColor Green

# 2. Applica l'immagine Windows
Write-Host "Applying Windows image..." -ForegroundColor Yellow
$ImageFile = "D:\OSDCloud\OS\Win_Pro_11_24H2_Italian.wim"

if (!(Test-Path $ImageFile)) {
    Write-Host "ERROR: Image file not found at $ImageFile" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Expand-WindowsImage -ImagePath $ImageFile -Index 1 -ApplyPath "W:\" -Verify

Write-Host "Windows image applied successfully!" -ForegroundColor Green

# 3. Configura il boot
Write-Host "Configuring boot..." -ForegroundColor Yellow
bcdboot W:\Windows /s S: /f UEFI

Write-Host "Boot configuration completed!" -ForegroundColor Green

# 4. Copia i driver (opzionale)
if (Test-Path "D:\Drivers") {
    Write-Host "Copying drivers..." -ForegroundColor Yellow
    robocopy "D:\Drivers" "W:\Drivers" /E /MT:8 /R:1 /W:1 /NFL /NDL /NP
}

Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "Remove installation media and press Enter to restart..." -ForegroundColor Yellow
Read-Host

Restart-Computer -Force


function Get-Hypervisor {
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem
        $bios = Get-CimInstance -ClassName Win32_BIOS
        $man = ($cs.Manufacturer, $cs.Model, $bios.Manufacturer, $bios.SMBIOSBIOSVersion) -join ' '
        switch -Regex ($man) {
            "Xen|Citrix"         { return "Xen" }
            "KVM|QEMU|Red Hat"   { return "KVM" }
            "VMware"             { return "VMware" }
            "Microsoft|Hyper-V"  { return "HyperV" }
            default              { return "Physical" }
        }
    } catch { return "Unknown" }
}

#################################################################
#   [PreOS] Update Module
#################################################################
Write-Host -ForegroundColor Green "Updating OSD PowerShell Module"
Install-Module OSD -Force -ErrorAction SilentlyContinue
#Install-Module OSD -RequiredVersion 25.10.17.3 -Force -SkipPublisherCheck

Write-Host  -ForegroundColor Green "Importing OSD PowerShell Module"
Import-Module OSD -Force   

#################################################################
#   [OS] Params and Start-OSDCloud
#################################################################
$LocalESD = "D:\OSDCloud\OS\win11_25h2_it-it-i8.wim"
#$Global:ImageFileFullName = $LocalESD
#$Global:ImageIndex = 1


$Params = @{
    ZTI = $true
    Firmware = $false
    SkipAutopilot = $true
    FindImage = $false
    #ImageIndex = 2
    ImageFile = $LocalESD
}

$Params = @{
    OSVersion = "Windows 11"
    OSBuild = "25H2"
    OSEdition = "Pro"
    OSLanguage = "it-it"
    OSLicense = "Retail"
    ZTI = $true
    Firmware = $false
    SkipAutopilot = $true
}

#Start-OSDCloud @Params
#Write-Host "Copying WIM file to local disk..." -ForegroundColor Cyan
#New-Item -Path "C:\OSDCloud\OS" -ItemType Directory -Force -ErrorAction SilentlyContinue
##Copy-Item -Path "D:\OSDCloud\OS\win11_25h2_it-it-i8.wim" -Destination "C:\OSDCloud\OS\" -Force -Verbose

$LocalWim = "D:\OSDCloud\OS\Win_Pro_11_24H2_Italian.wim"
Start-OSDCloud -ZTI  -ImageFile $LocalWim -OSImageIndex 1 -SkipAutopilot

#################################################################
#  [PostOS] OOBE CMD Command Line
#################################################################
Write-Host -ForegroundColor Green "Downloading and creating script for OOBE phase"
New-Item -Path "C:\Windows\Setup\Scripts" -ItemType Directory -Force | Out-Null

# Certificate
##Copy-Item -Path "X:\OSDCloud\Config\Scripts\SetupComplete\RootCA.cer" -Destination "C:\OSDCloud\Scripts\SetupComplete\RootCA.cer" -Force
Copy-Item -Path "X:\OSDCloud\Config\Scripts\SetupComplete\SetupComplete.cmd" -Destination "C:\OSDCloud\Scripts\SetupComplete\SetupComplete.cmd" -Force
Copy-Item -Path "X:\OSDCloud\Config\Scripts\SetupComplete\SetupComplete.ps1" -Destination "C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1" -Force

Write-Host  -ForegroundColor Green "Nic copy driver install"
#copy-Item -Path "X:\OSDCloud\Config\Scripts\SetupComplete\managementagentx64.msi" -Destination "C:\OSDCloud\Scripts\SetupComplete\managementagentx64.msi" -Force

# Drivers
New-Item -Path "C:\Drivers" -ItemType Directory -Force | Out-Null
$hv = Get-Hypervisor
if ($hv -eq "Xen" -and (Test-Path $citrixMsi)) {
   Robocopy X:\OSDCloud\Config\Drivers\Xen\ C:\Drivers\ /E /r:0 /w:0
}
if ($hv -eq "KVM" -and (Test-Path $citrixMsi)) {
   Robocopy X:\OSDCloud\Config\Drivers\Virtio\ C:\Drivers\ /E /r:0 /w:0
}
if ($hv -eq "Xen" -and (Test-Path $citrixMsi)) {
   Robocopy X:\OSDCloud\Config\Drivers\VMware\ C:\Drivers\ /E /r:0 /w:0
}
if ($hv -eq "Xen" -and (Test-Path $citrixMsi)) {
   Robocopy X:\OSDCloud\Config\Drivers\Physical\ C:\Drivers\ /E /r:0 /w:0
}

$OOBEScript = "Updates_Activation.ps1"
Invoke-RestMethod   -Uri "https://raw.githubusercontent.com/gitzenvoo/Windows11/refs/heads/main/OSDCloud/OOBE/SplashScreen/$OOBEScript" `
                    -OutFile "C:\Windows\Setup\Scripts\$OOBEScript"

$OOBECMD = @"
@echo off
call :LOG > C:\Windows\Setup\Scripts\oobe.log
exit /B

:LOG

set LOCALAPPDATA=%USERPROFILE%AppDataLocal
set PSExecutionPolicyPreference=Unrestricted

##certutil -addstore root C:\OSDCloud\Scripts\SetupComplete\RootCA.cer

powershell.exe -Command Get-NetIPAddress
powershell.exe -Command Set-ExecutionPolicy Unrestricted -Force

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\$OOBEScript"
 
"@
$OOBECMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\oobe.cmd' -Encoding ascii -Force

#################################################################
#   [PostOS] Restart-Computer
#################################################################

10..1 | ForEach-Object{
    Write-Progress -Activity "Computer Restart" -Status "in $_ seconds"
    Start-Sleep -seconds 1
 }
Restart-Computer -Force

