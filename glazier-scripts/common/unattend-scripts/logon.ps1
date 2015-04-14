$ErrorActionPreference = "Stop"
$resourcesDir = "$ENV:SystemDrive\UnattendResources"
$configIniPath = "$resourcesDir\config.ini"

try
{
    $needsReboot = $false

    Import-Module "$resourcesDir\ini.psm1"
    $installUpdates = Get-IniFileValue -Path $configIniPath -Section "DEFAULT" -Key "InstallUpdates" -Default $false -AsBoolean

    if($installUpdates)
    {
        if (!(Test-Path "$resourcesDir\PSWindowsUpdate"))
        {
            #Fixes Windows Server 2008 R2 inexistent Unblock-File command Bug
            if ($(Get-Host).version.major -eq 2)
            {
                $psWindowsUpdatePath = "$resourcesDir\PSWindowsUpdate_1.4.5.zip"
            }
            else
            {
                $psWindowsUpdatePath = "$resourcesDir\PSWindowsUpdate.zip"
            }

            & "$resourcesDir\7za.exe" x $psWindowsUpdatePath -o"$resourcesDir"
            if($LASTEXITCODE) { throw "7za.exe failed to extract PSWindowsUpdate" }
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

        $Host.UI.RawUI.WindowTitle = "Setting up print password script ..."
        $originalPrintPasswordScript = Join-Path ${resourcesDir} 'printPassword.ps1'
        $printPasswordScript = "$programFilesDir\Cloudbase Solutions\Cloudbase-Init\LocalScripts\printPassword.ps1"
        Copy-Item -Force $originalPrintPasswordScript $printPasswordScript

        $Host.UI.RawUI.WindowTitle = "Setting up first run script ..."
        $originalFirstRunScript = Join-Path ${resourcesDir} 'firstRun.ps1'
        $firstRunScript = "$programFilesDir\Cloudbase Solutions\Cloudbase-Init\LocalScripts\firstRun.ps1"
        Copy-Item -Force $originalFirstRunScript $firstRunScript

        $infoDir = "$ENV:SystemRoot\als_image"
        if (!(Test-Path $infoDir))
        {
           mkdir $infoDir
        }

        # Install WinRM hotfix
        $Host.UI.RawUI.WindowTitle = "Installing KB2842230 ..."
        $winRMHotfixScript = Join-Path ${resourcesDir} 'hotfix-KB2842230.bat'
        $winRMHotfixLog = Join-Path ${infoDir} 'winRMHotfix.log'
        $hotfixProcess = Start-Process -Wait -PassThru -FilePath "cmd.exe" -ArgumentList "/c ${winRMHotfixScript} 2>&1 1> ${winRMHotfixLog}"
        if ($hotfixProcess.ExitCode -ne 0)
        {
            throw "Installing $winRMHotfixScript failed. Log: $winRMHotfixLog"
        }

        # Compile .NET assemblies
        $Host.UI.RawUI.WindowTitle = "Compiling .NET assemblies ..."
        $compileDotNetAssembliesScript = Join-Path ${resourcesDir} 'compile-dotnet-assemblies.bat'
        $compileDotNetAssembliesLog = Join-Path ${infoDir} 'dotNetCompile.log'
        $compileProcess = Start-Process -Wait -PassThru -FilePath "cmd.exe" -ArgumentList "/c ${compileDotNetAssembliesScript} 2>&1 1> ${compileDotNetAssembliesLog}"
        if ($compileProcess.ExitCode -ne 0)
        {
            throw "Installing $compileDotNetAssembliesScript failed. Log: $compileDotNetAssembliesLog"
        }

        # Save the compact script
        $originalCompactScript = Join-Path ${resourcesDir} 'compact.bat'
        $compactScript = 'c:\windows\temp\compact.bat'
        Copy-Item -Force $originalCompactScript $compactScript

        # Cleanup
        Remove-Item -Recurse -Force $resourcesDir
        Remove-Item -Force "$ENV:SystemDrive\Unattend.xml"

        # We're done, disable AutoLogon
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name Unattend*
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount

        # Cleanup of Windows Updates
        & Dism.exe /online /Cleanup-Image /StartComponentCleanup

        # Compact
        $Host.UI.RawUI.WindowTitle = "Compacting image ..."
        $compactLog = Join-Path ${infoDir} 'compact.log'
        $compactProcess = Start-Process -Wait -PassThru -FilePath "cmd.exe" -ArgumentList "/c ${compactScript} 2>&1 1> ${compactLog}"
        if ($compactProcess.ExitCode -ne 0)
        {
            throw "Installing $compactScript failed. Log: $compactLog"
        }

        $Host.UI.RawUI.WindowTitle = "Running SetSetupComplete..."
        & "$programFilesDir\Cloudbase Solutions\Cloudbase-Init\bin\SetSetupComplete.cmd"

        $Host.UI.RawUI.WindowTitle = "Running Sysprep..."
        $unattendedXmlPath = "$programFilesDir\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"
        & "$ENV:SystemRoot\System32\Sysprep\Sysprep.exe" `/generalize `/oobe `/shutdown `/unattend:"$unattendedXmlPath"
    }
}
catch
{
    $host.ui.WriteErrorLine($_.Exception.ToString())
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    throw
}
