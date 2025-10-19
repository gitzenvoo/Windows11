<#
.SYNOPSIS
    Displays a Splash Screen to Installs the latest Windows 10/11 quality updates + activates Windows. 

.NOTES
    FileName:    Updates-and-Activation.ps1
    Author:      ITAE
    Created:     2025-02-10

    Version history:
    1.0 - (2025-02-10) Script created


#>
$Scripts2run = @(
  @{
    Name = "Windows Drivers"
    Script = "https://raw.githubusercontent.com/gitzenvoo/Windows11/refs/heads/main/OSDCloud/OOBE/Windows-Drivers.ps1"
  },
  @{
    Name = "Enabling built-in Windows Producy Key"
    Script = "https://raw.githubusercontent.com/gitzenvoo/Windows11/refs/heads/main/OSDCloud/OOBE/Set-EmbeddedWINKey.ps1"
  },
  @{
    Name = "Windows Quality Updates"
    Script = "https://raw.githubusercontent.com/gitzenvoo/Windows11/refs/heads/main/OSDCloud/OOBE/Windows-Updates_Quality.ps1"
  },
  @{
    Name = "Windows Firmware and Driver Updates"
    Script = "https://raw.githubusercontent.com/gitzenvoo/Windows11/refs/heads/main/OSDCloud/OOBE/Windows-Updates_DriverFirmware.ps1"
  },
  @{
    Name = "Saving Logs and Cleanup"
    Script = "https://raw.githubusercontent.com/gitzenvoo/Windows11/refs/heads/main/OSDCloud/OOBE/OSDCloud-CleanUp.ps1"
  }
)

Write-Host "Starting Windows Updates and Activation"

##C:\OSDCloud\Scripts\SetupComplete\NicDriver.msi /qn

# Wait for network connectivity
Write-Host "Waiting for network connectivity..."

# Loop to check for active network connection
##while ($true) {
##    $connectionTest = Test-NetConnection -ComputerName 8.8.8.8 -Port 443
##    if ($connectionTest.TcpTestSucceeded) {
##        Write-Host "Network connection detected!"
##        break
##    } else {
##        Write-Host "No network connection. Retrying in 5 seconds..."
##        Start-Sleep -Seconds 5
##    }
##}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -Force | Out-Null
Install-Script Start-SplashScreen -Force | Out-Null

Start-SplashScreen.ps1 -Processes $Scripts2run
