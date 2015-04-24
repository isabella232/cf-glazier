$ErrorActionPreference = "Stop"
$resourcesDir = "$ENV:SystemDrive\glazier"

try
{
  $fileSystemAssemblyPath = Join-Path ([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'System.IO.Compression.FileSystem.dll'
  Add-Type -Path $fileSystemAssemblyPath

  $needsReboot = $false

  if (!(Test-Path "$resourcesDir\PSWindowsUpdate"))
  {
    $psWindowsUpdatePath = "$resourcesDir\PSWindowsUpdate.zip"

    [System.IO.Compression.ZipFile]::ExtractToDirectory($psWindowsUpdatePath, $resourcesDir)
  }

  $Host.UI.RawUI.WindowTitle = "Installing updates..."

  Import-Module "$resourcesDir\PSWindowsUpdate"

  Get-WUInstall -AcceptAll -IgnoreReboot -IgnoreUserInput -NotCategory "Language packs"
  if (Get-WURebootStatus -Silent)
  {
    $needsReboot = $true
    $Host.UI.RawUI.WindowTitle = "Updates installation finished. Rebooting."
    shutdown /r /t 0
  }

  if(!$needsReboot)
  {
    $Host.UI.RawUI.WindowTitle = "Installing Cloudbase-Init..."

    $osArch = (Get-WmiObject  Win32_OperatingSystem).OSArchitecture
    if($osArch -eq "64-bit")
    {
        $programFilesDir = ${ENV:ProgramFiles(x86)}
    }
    else
    {
        $programFilesDir = $ENV:ProgramFiles
    }

    $CloudbaseInitMsiPath = "$resourcesDir\CloudbaseInit.msi"
    $CloudbaseInitMsiLog = "$resourcesDir\CloudbaseInit.log"

    $serialPortName = @(Get-WmiObject Win32_SerialPort)[0].DeviceId

    $p = Start-Process -Wait -PassThru -FilePath msiexec -ArgumentList "/i $CloudbaseInitMsiPath /qn /l*v $CloudbaseInitMsiLog LOGGINGSERIALPORTNAME=$serialPortName"
    if ($p.ExitCode -ne 0)
    {
        throw "Installing $CloudbaseInitMsiPath failed. Log: $CloudbaseInitMsiLog"
    }

    $infoDir = "$ENV:SystemRoot\glazier_image"
    if (!(Test-Path $infoDir))
    {
       mkdir $infoDir
    }

    # Copy the print password script
    $Host.UI.RawUI.WindowTitle = "Setting up print password script ..."
    $originalPrintPasswordScript = Join-Path ${resourcesDir} 'print-password.ps1'
    $printPasswordScript = "$programFilesDir\Cloudbase Solutions\Cloudbase-Init\LocalScripts\printPassword.ps1"
    Copy-Item -Force $originalPrintPasswordScript $printPasswordScript

    # Copy the unattend xml
    $Host.UI.RawUI.WindowTitle = "Copying unattend xml ..."
    $originalUnattendXML = Join-Path ${resourcesDir} 'first-boot-unattend.xml'
    $unattendXML = Join-Path $infoDir 'unattend.xml'
    Copy-Item -Force $originalUnattendXML $unattendXML

    # Compile .NET assemblies
    $Host.UI.RawUI.WindowTitle = "Compiling .NET assemblies ..."
    $compileDotNetAssembliesScript = Join-Path ${resourcesDir} 'compile-dotnet-assemblies.bat'
    $compileDotNetAssembliesLog = Join-Path ${infoDir} 'dotNetCompile.log'
    $compileProcess = Start-Process -Wait -PassThru -FilePath "cmd.exe" -ArgumentList "/c ${compileDotNetAssembliesScript} 2>&1 1> ${compileDotNetAssembliesLog}"
    if ($compileProcess.ExitCode -ne 0)
    {
        throw "Running $compileDotNetAssembliesScript failed. Log: $compileDotNetAssembliesLog"
    }

    # Save the compact script and unpack/save utilities
    # unpack sdelete
    $Host.UI.RawUI.WindowTitle = "Saving compact utilities ..."
    $sdeleteZip = Join-Path ${resourcesDir} 'sdelete.zip'
    $sdeleteUnpackLocation = Join-Path ${env:WINDIR} 'temp'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($sdeleteZip, $sdeleteUnpackLocation)
    # unpack ultradefrag
    $ultraDefragZip = Join-Path ${resourcesDir} 'ultradefrag.zip'
    $ultraDefragUnpackLocation = Join-Path ${env:WINDIR} 'temp'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ultraDefragZip, $ultraDefragUnpackLocation)
    # save compact script
    $originalCompactScript = Join-Path ${resourcesDir} 'compact.bat'
    $compactScript = 'c:\windows\temp\compact.bat'
    Copy-Item -Force $originalCompactScript $compactScript

    # Cleanup
    $Host.UI.RawUI.WindowTitle = "Removing glazier dir ..."
    Remove-Item -Recurse -Force $resourcesDir
    Remove-Item -Force "$ENV:SystemDrive\Unattend.xml"

    # We're done, disable AutoLogon
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name Unattend*
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount

    # Cleanup of Windows Updates
    $Host.UI.RawUI.WindowTitle = "Running DISM ..."
    & Dism.exe /online /Cleanup-Image /StartComponentCleanup

    # Compact
    $Host.UI.RawUI.WindowTitle = "Compacting image ..."
    $compactLog = Join-Path ${infoDir} 'compact.log'
    $compactProcess = Start-Process -Wait -PassThru -FilePath "cmd.exe" -ArgumentList "/c ${compactScript} 2>&1 1> ${compactLog}"
    if ($compactProcess.ExitCode -ne 0)
    {
        throw "Running $compactScript failed. Log: $compactLog"
    }

    $Host.UI.RawUI.WindowTitle = "Running SetSetupComplete..."
    & "$programFilesDir\Cloudbase Solutions\Cloudbase-Init\bin\SetSetupComplete.cmd"

    & ipconfig /release

    $Host.UI.RawUI.WindowTitle = "Running Sysprep..."
    & "$ENV:SystemRoot\System32\Sysprep\Sysprep.exe" `/generalize `/oobe `/shutdown `/unattend:"$unattendXML"
  }
}
catch
{
    $host.ui.WriteErrorLine($_.Exception.ToString())
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    throw
}
