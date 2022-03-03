<#
  .SYNOPSIS
  Wrapper script for MSIX deployment via IntuneWin32 Application.

  .DESCRIPTION
  MSIX or MSIXbundle files are expected to be in src. Script has three modes. Detect, Install and Uninstall. 
  Configure the Manifest section with the application details
  Detect is the default mode if Mode switch is not specified
  Logs to C:\ProgramData\Microsoft\IntuneManagementExtension\Logs
  Intune Program Properties: Install command   : powershell.exe -ExecutionPolicy Bypass -File Manage-MSIX.ps1 -Mode Install
                             Uninstall command : powershell.exe -ExecutionPolicy Bypass -File Manage-MSIX.ps1 -Mode Uninstall
                             Install behavior  : System

  .EXAMPLE
  PS> .\Manage-MSIX.ps1

  .EXAMPLE
  PS> .\Manage-MSIX.ps1 -Mode Install

  .EXAMPLE
  PS> .\Manage-MSIX.ps1 -Mode Uninstall
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Detect', 'Install', 'Uninstall')]
    $Mode = "Detect"

)
#region Changes Here
# Use Get-ProvisionedAppPackage -online to find DisplayName and Version
$Manifest = @{
    Application = @(
        @{
            Name              = "Your Application"
            Version           = "1.1.1.1"
            DisplayName       = "Your.Application"
        }
    )
}
#endregion

#region Declarations 
$LogFilePath = Join-Path $env:ProgramData "Microsoft\IntuneManagementExtension\Logs\MSIXIntuneWinWrapper-$($Manifest.Application.Name)-$($Manifest.Application.Version)-$(Get-Date -Format yyyy-M-dd).log"
$AppNameAndVersion = "(Name: $($Manifest.Application.Name) Version: $($Manifest.Application.Version))"
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
#endregion

#region Functions
function Write-Log {
    #https://janikvonrotz.ch/2017/10/26/powershell-logging-in-cmtrace-format/
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [String]$Path,

        [parameter(Mandatory = $true)]
        [String]$Message,

        [parameter(Mandatory = $true)]
        [String]$Component,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Info", "Warning", "Error")]
        [String]$Type
    )

    switch ($Type) {
        "Info" { [int]$Type = 1 }
        "Warning" { [int]$Type = 2 }
        "Error" { [int]$Type = 3 }
    }

    # Create a log entry
    $Content = "<![LOG[$Message]LOG]!>" + `
        "<time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" " + `
        "date=`"$(Get-Date -Format "M-d-yyyy")`" " + `
        "component=`"$Component`" " + `
        "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + `
        "type=`"$Type`" " + `
        "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " + `
        "file=`"`">"

    # Write the line to the log file
    Add-Content -Path $Path -Value $Content
}

function Install {
    Write-Log -Path $LogFilePath -Message "Try to install $AppNameAndVersion" -Component $Mode -Type Info
    $MSIXs = Get-Childitem -Path $ScriptDirectory\src -Include *.msix, *.msixbundle -File -Recurse -ErrorAction SilentlyContinue
    If (($MSIXs | Measure-Object).Count -ge 1) {
        Write-Log -Path $LogFilePath -Message "Found $(($MSIXs | Measure-Object).Count) Installer Files" -Component $Mode -Type Info
        foreach ($MSIX in $MSIXs) {
            Write-Log -Path $LogFilePath -Message "Start to install $($MSIX.FullName)" -Component $Mode -Type Info
            try {
                Add-AppProvisionedPackage -online -packagepath ($MSIX.FullName) -skiplicense | Out-Null 
                Write-Log -Path $LogFilePath -Message "Installation of $($MSIX.FullName) done" -Component $Mode -Type Info
            }
            catch {
                Write-Error ($_ | Out-String)
                Write-Log -Path $LogFilePath -Message ($_ | Out-String) -Component $Mode -Type Error
            }
        }
    }
    else {
        Write-Log -Path $LogFilePath -Message "No Installer Files found" -Component $Mode -Type Warning
    }
}

function Uninstall {
    Write-Log -Path $LogFilePath -Message "Try to uninstall $AppNameAndVersion with DisplayName $($manifest.Application.DisplayName)" -Component $Mode -Type Info
   
    $Apps = Get-ProvisionedAppPackage -online | Where-Object DisplayName -eq $($manifest.Application.DisplayName)  
    if ($Apps.count -ge 1) {
        Write-Log -Path $LogFilePath -Message "Application $AppNameAndVersion is installed, continue to uninstall" -Component $Mode -Type Info
        foreach ($App in $Apps) {
            Write-Log -Path $LogFilePath -Message "Start to uninstall $AppNameAndVersion with DisplayName $($App.DisplayName)" -Component $Mode -Type Info
            try {
                $App | Remove-ProvisionedAppPackage -Online -AllUsers | Out-Null
                Write-Log -Path $LogFilePath -Message "Uninstallation of $AppNameAndVersion with DisplayName $($App.DisplayName) done" -Component $Mode -Type Info
            }
            catch {
                Write-Error ($_ | Out-String)
                Write-Log -Path $LogFilePath -Message ($_ | Out-String) -Component $Mode -Type Error
            }
        }
    }
    else {
        Write-Log -Path $LogFilePath -Message "$($Manifest.Application.Name) already uninstalled" -Component $Mode -Type Info
    }
}

function Detect {
    Write-Log -Path $LogFilePath -Message "Search $AppNameAndVersion with DisplayName $($Manifest.Application.DisplayName)" -Component $Mode -Type Info
    $Apps = Get-ProvisionedAppPackage -online | Where-Object DisplayName -eq $($manifest.Application.DisplayName)  
    if ($Apps.count -ge 1) {
        Write-Log -Path $LogFilePath -Message "Found $($Apps.count) instances $AppNameAndVersion with DisplayName $($manifest.Application.DisplayName)" -Component $Mode -Type Info
        Write-Log -Path $LogFilePath -Message "[end with exit code 0 mode was ""$Mode""]" -Component $Mode -Type Info
        Write-Host "Found it!"
        exit(0)
    }
    else {
        Write-Log -Path $LogFilePath -Message "Coudn't find $AppNameAndVersion with DisplayName $($manifest.Application.DisplayName),seems not to be installed" -Component $Mode -Type Warning
        Write-Log -Path $LogFilePath -Message "[end with exit code 1 mode was ""$Mode""]" -Component $Mode -Type Info
        exit(1)
    }
}
#endregion

#region Logic
Write-Log -Path $LogFilePath -Message "[start mode is ""$Mode""]" -Component $Mode -Type Info
switch ($Mode) {
    'Detect' { Detect }
    'Install' { Install }
    'Uninstall' { Uninstall }
}
Write-Log -Path $LogFilePath -Message "[end mode was ""$Mode""]" -Component $Mode -Type Info
#endregion