# MSIXIntunewinWrapper
## Description


## Guide
>MSIX or MSIXbundle files are expected to be in src folder. 

>Script has three modes. Detect, Install and Uninstall.
>Detect is the default mode if Mode switch is not specified

>Configure the Manifest section with the application details

>Logs to C:\ProgramData\Microsoft\IntuneManagementExtension\Logs

<dl>
  <dt>Intune Program Properties</dt>
  <dd>Install command   : powershell.exe -ExecutionPolicy Bypass -File Manage-MSIX.ps1 -Mode Install</dd>
  <dd>Uninstall command : powershell.exe -ExecutionPolicy Bypass -File Manage-MSIX.ps1 -Mode Uninstall</dd>
  <dd>Install behavior  : System</dd>
</dl>

## TODO
- [ ] Dependencies
- [ ] Readme Update
- [ ] Microsoft-Win32-Content-Prep-Tool Guide  

## Thanks
[Yanik von Rotz](https://janikvonrotz.ch) for the Write-Log function https://janikvonrotz.ch/2017/10/26/powershell-logging-in-cmtrace-format/