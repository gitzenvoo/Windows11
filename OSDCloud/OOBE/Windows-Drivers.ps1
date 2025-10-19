<#
.SYNOPSIS
    Installs the drivers.

.NOTES
    FileName:    Windows-Drivers.ps1
    Author:      ITAE
    Created:     2025-10-18


    Version history:
        2025-02-10, 1.0:    Script created.

#>


[CmdletBinding()]
Param(
    [Parameter(Mandatory = $False)] 
    [ValidateSet('Soft', 'Hard', 'None', 'Delayed')] 
    [String] $Reboot = 'None',
    
    [Parameter(Mandatory = $False)] 
    [Int32] $RebootTimeout = 10 # seconds
)

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
            default              { return "Physical/Other" }
        }
    } catch { return "Unknown" }
}

Process {

    # If running as a 32-bit process on an x64 system, re-launch as a 64-bit process
    if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64" -and (Test-Path "$env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe")) {
        & "$env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
        Exit $lastexitcode
    }

    # Start logging
    Start-Transcript "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Windows-Drivers.log" | Out-Null

    Write-Host "Installing Windows Drivers ..."

    # Opt into Microsoft Update
    $ts = Get-Date -Format "yyyy/MM/dd hh:mm:ss tt"
    Write-Output "$ts Opting into Microsoft Update"
    $ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
    $ServiceID = "7971f918-a847-4430-9279-4a52d1efe18d"
    $ServiceManager.AddService2($ServiceId, 7, "") | Out-Null

    # Install available firmware and drivers updates
    $hv = Get-Hypervisor
    write-Host "$ts Hypervisor: $hv"
    Write-Output "$ts Hypervisor: $hv"

    $citrixMsi = "C:\Drivers\managementagentx64.msi"
    if ($hv -eq "Xen" -and (Test-Path $citrixMsi)) {
    write-Host "$ts Install Citrix/Xen Tools"
    Write-Output "$ts Install Citrix/Xen Tools"
    Start-Process msiexec.exe -ArgumentList @('/i', $citrixMsi, '/qn', '/norestart') -Wait

    $VirtioExe = "C:\Drivers\Virtio\virtio-win-guest-tools.exe"
    if ($hv -eq "KVM" -and (Test-Path $virtioExe)) {
    write-Host "$ts Install Virtio Tools"
    Write-Output "$ts Install Virtio Tools"
    Start-Process "$virtioExe" -ArgumentList @('/qn','/norestart') -Wait
}
}

    # Reboot handling
    $ts = Get-Date -Format "yyyy/MM/dd hh:mm:ss tt"
    if ($script:needReboot) {
        Write-Host "$ts Windows Update indicated that a reboot is needed."
    } else {
        Write-Host "$ts Windows Update indicated that no reboot is required."
    }

    if ($Reboot -eq "Hard") {
        Write-Host "$ts Exiting with return code 1641 to indicate a hard reboot is needed." -ForegroundColor Cyan
        Stop-Transcript
        #Exit 1641
    } elseif ($Reboot -eq "Soft") {
        Write-Host "$ts Exiting with return code 3010 to indicate a soft reboot is needed." -ForegroundColor Cyan
        Stop-Transcript
        #Exit 3010
    } elseif ($Reboot -eq "Delayed") {
        Write-Host "$ts Rebooting with a $RebootTimeout second delay" -ForegroundColor Cyan
        & shutdown.exe /r /t $RebootTimeout /c "Rebooting to complete the installation of Windows updates." 
        Exit 0
    } else {
        Write-Host "$ts Skipping reboot based on Reboot parameter (None)" -ForegroundColor Cyan
        #Exit 0
    }
}
