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

Write-Host  -ForegroundColor Green "Importing OSD PowerShell Module"
#Import-Module OSD -Force   
Import-Module OSD -RequiredVersion 25.10.17.3 -Force
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

##$Params = @{
    #OSVersion = "Windows 11"
    #OSBuild = "25H2"
    #OSEdition = "Pro"
    #OSLanguage = "it-it"
    #OSLicense = "Retail"
    ##ZTI = $true
    ##Firmware = $false
    ##SkipAutopilot = $true
    #FindImage = $false
    ##ImageIndex = 1
    ##ImageFile = $LocalESD
##}
#Start-OSDCloud @Params -OSImageIndex 2
$LocalPath = "D:\OSDCloud\OS\win11_25h2_it-it-i8.wim"
Start-OSDCloud -ZTI -FindImage:$false -ImageFile $LocalESD -ImageIndex 1 -SkipAutopilot

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

