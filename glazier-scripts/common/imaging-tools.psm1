$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
Import-Module -DisableNameChecking (Join-Path $currentDir './utils.psm1')

function CheckIsAdmin{[CmdletBinding()]param()
    $wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $prp = new-object System.Security.Principal.WindowsPrincipal($wid)
    $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $isAdmin = $prp.IsInRole($adm)
    if(!$isAdmin)
    {
        throw "This cmdlet must be executed in an elevated administrative shell"
    }
}

function Validate-WindowsWIM{[CmdletBinding()]param($wimPath)
  if ((Test-Path $wimPath) -eq $false)
  {
    throw "WIM file ${wimPath} does not exist!"
  }

  try
  {
    $wimInfo = Get-WindowsImage -ImagePath $wimPath -Index 1

    if ($wimInfo.ImageName -ne 'Windows Server 2012 R2 SERVERSTANDARDCORE')
    {
      throw "Did not find image 'Windows Server 2012 R2 SERVERSTANDARDCORE' at index 0 for wim '${wimPath}'."
    }

    if ($wimInfo.Languages[0] -ne 'en-us')
    {
      throw "Incorrect language detected for wim '${wimPath}'; en-us is the only supported language."
    }
  }
  catch
  {
    Write-Verbose $_.Exception
    $exceptionMessage = $_.Exception.Message
    throw "Error while trying to validate wim file ${wimPath}: ${exceptionMessage}"
  }
}

function CreateAndMount-VHDImage{[CmdletBinding()]param($vhdPath, $sizeInBytes, [ref]$vhdMountLetter)
  $diskpartScriptPath = "${vhdPath}.diskpart"

  $diskPartScript = @"
create vdisk file="${vhdPath}" maximum=${sizeInBytes} type=expandable
select vdisk file="${vhdPath}"
attach vdisk
create partition primary
assign
format fs="ntfs" label="System" quick
active
detach vdisk
exit
"@

  $diskPartScript | Out-File -Encoding 'ASCII' $diskpartScriptPath

  $diskpartProcess = Start-Process -Wait -PassThru -NoNewWindow 'diskpart' "/s `"${diskpartScriptPath}`""

  if ($diskpartProcess.ExitCode -ne 0)
  {
    throw 'Creating and formatting vhd failed.'
  }

  try
  {
    # Try to mount the new vhd
    $maxAttempts = 15
    for($i=1; $i -le $maxAttempts; $i++)
    {
      try
      {
        Write-Output "Trying to mount '${vhdPath}'. Attempt ${i} of ${maxAttempts} ..."

        Mount-DiskImage -ImagePath $vhdPath -StorageType VHD -ErrorAction 'Stop'

        $drive = (Get-DiskImage -ImagePath $vhdPath | Get-Disk | Get-Partition | Get-Volume).DriveLetter
        $vhdMountLetter.Value = $drive
        Write-Verbose "VHD mounted successfully at ${drive}."

        New-PSDrive -Name $drive -PSProvider FileSystem -Root "${drive}:\" -Scope Global -ErrorAction 'SilentlyContinue' | out-null

        # Try to list the new mounted letter
        for($j=1; $j -le $maxAttempts; $j++)
        {
          try
          {
            Write-Output "Trying to list '${drive}:\'. Attempt ${j} of ${maxAttempts} ..."
            Get-ChildITem -ErrorAction 'Stop' -Path "${drive}:"
            Write-Verbose "Accessed '${drive}:' successfuly."
            return
          }
          catch
          {
            $exceptionMessage = $_.Exception.Message
            Write-Verbose "Could access '${drive}': ${exceptionMessage}"
            Start-Sleep -Seconds 1
          }
        }

        break;
      }
      catch
      {
        $exceptionMessage = $_.Exception.Message
        Write-Verbose "Could not mount '${vhdPath}': ${exceptionMessage}"
        Start-Sleep -Seconds 1
      }
    }

    throw "Could not mount '${vhdPath}'."
  }
  catch
  {
    Write-Verbose $_.Exception
    $exceptionMessage = $_.Exception.Message
    throw "Mounting vhd failed: ${exceptionMessage}"
  }
}


function Dismount-VHDImage{[CmdletBinding()]param($vhdPath)
  try
  {
    Dismount-DiskImage -ImagePath $vhdPath -PassThru -ErrorAction Stop
    Write-Verbose "Dismounted vhd successfully."
  }
  catch
  {
    Write-Verbose $_.Exception
    $exceptionMessage = $_.Exception.Message
    throw "Error while trying to dismount vhd ${vhdPath}: ${exceptionMessage}"
  }
}

function Apply-Image{[CmdletBinding()]param($wimPath, $vhdMountLetter)
  $dismProcess = Start-Process -Wait -PassThru -NoNewWindow 'dism.exe' "/apply-image /imagefile:${wimPath} /index:1 /ApplyDir:${vhdMountLetter}:\"

  if ($dismProcess.ExitCode -ne 0)
  {
    throw "Error while trying to apply wim '${wimPath}' to vhd mounted at '${vhdMountLetter}:\': ${exceptionMessage}"
  }
  else
  {
    Write-Verbose "Applied windows image successfully."
  }
}

function Create-BCDBootConfig{[CmdletBinding()]param($vhdMountLetter)
    $bcdbootPath = "${vhdMountLetter}:\windows\system32\bcdboot.exe"

    $bcdbootProcess = Start-Process -Wait -PassThru -NoNewWindow $bcdbootPath "${vhdMountLetter}:\windows /s ${vhdMountLetter}: /v"

    if ($bcdbootProcess.ExitCode -ne 0)
    {
      throw 'Running bcdboot failed.'
    }
    else
    {
      Write-Verbose "bcdboot ran successfully."
    }
}

function Add-VirtIODriversToImage{[CmdletBinding()]param($vhdMountLetter, $virtioPath)
  try
  {
    Add-WindowsDriver -Path "${vhdMountLetter}:\" -Driver "${virtioPath}\WIN8\AMD64" -ForceUnsigned -Recurse
    Write-Verbose 'VirtIO drivers addded successfully'
  }
  catch
  {
    Write-Verbose $_.Exception
    $exceptionMessage = $_.Exception.Message
    throw "Error while trying to add VirtIO drivers from '${virtioPath}' to vhd mounted at '${vhdMountLetter}:\': ${exceptionMessage}"
  }
}

function Set-DesiredFeatureStateInImage{[CmdletBinding()]param($vhdMountLetter, $featureFile, $wimPath)
  $features = Import-Csv $featureFile

  $removedFeatures = $features | Where-Object { $_.desired -eq 'Removed' }

  $disabledFeatures = $features | Where-Object { $_.desired -eq 'Disabled' }

  $enabledFeatures = $features | Where-Object { $_.desired -eq 'Enabled' }

  foreach ($feature in $removedFeatures)
  {
    $featureName = $feature.Feature

    Write-Verbose "Removing feature '${featureName}'"
    Disable-WindowsOptionalFeature -Path "${vhdMountLetter}:\" -FeatureName ${featureName} -Remove -Verbose
  }

  foreach ($feature in $disabledFeatures)
  {
    $featureName = $feature.Feature

    Write-Verbose "Disabling feature '${featureName}'"
    Disable-WindowsOptionalFeature -Path "${vhdMountLetter}:\" -FeatureName ${featureName} -Verbose
  }

  foreach ($feature in $enabledFeatures)
  {
    $featureName = $feature.Feature

    Write-Verbose "Enabling feature '${featureName}'"
    Enable-WindowsOptionalFeature -Path "${vhdMountLetter}:\" -FeatureName ${featureName} -All -LimitAccess -Source $wimPath -Verbose
  }
}

function Add-UnattendScripts{[CmdletBinding()]param($vhdMountLetter)
  $destinationDir = "${vhdMountLetter}:\glazier\"
  $scriptsDir = Join-Path $currentDir 'unattend-scripts'
  $toolsCSVFile = Join-Path $scriptsDir 'tools.csv'

  try
  {
    Clean-Dir $destinationDir

    $tools = Import-Csv $toolsCSVFile

    foreach ($tool in $tools)
    {
      $destination = Join-Path $destinationDir $tool.destination
      Download-File $tool.Url $destination
    }

    Copy-Item -Recurse "${scriptsDir}\*" $destinationDir
  }
  catch
  {
    Write-Verbose $_.Exception
    $exceptionMessage = $_.Exception.Message
    throw "Error while trying to add unattend scripts to vhd mounted at '${vhdMountLetter}:\': ${exceptionMessage}"
  }
}

function Add-GlazierProfile{[CmdletBinding()]param($vhdMountLetter, $glazierProfile)
  $destinationDir = "${vhdMountLetter}:\glazier\profile"
  $profileDir = $glazierProfile.Path
  $toolsCSVFile = $glazierProfile.SpecializeToolsCSVFile

  try
  {
    Clean-Dir $destinationDir

    $tools = Import-Csv $toolsCSVFile

    foreach ($tool in $tools)
    {
      $destination = Join-Path $destinationDir $tool.destination
      Download-File $tool.Url $destination
    }

    Copy-Item -Recurse "${profileDir}\*" $destinationDir
  }
  catch
  {
    Write-Verbose $_.Exception
    $exceptionMessage = $_.Exception.Message
    throw "Error while trying to add glazier profile to vhd mounted at '${vhdMountLetter}:\': ${exceptionMessage}"
  }
}

function Add-UnattendXml{[CmdletBinding()]param($vhdMountLetter, $productKey)
  try
  {
    # Based on https://technet.microsoft.com/en-us/library/cc749415%28v=ws.10%29.aspx
    # Windows Setup will search for Unattend.xml in %SYSTEMDRIVE%
    $destinationFile = "${vhdMountLetter}:\Unattend.xml"
    $scriptsDir = Join-Path $currentDir 'unattend-scripts'
    $sourceFile = Join-Path $scriptsDir 'Unattend.xml'

    Write-Verbose "Configuring unattend file '${destinationFile}' based on '${sourceFile}' ..."
    [xml]$unattendXml = Get-Content $sourceFile

    $allComponents = $unattendXml.unattend.settings | foreach { $_.component }
    $windowsSetupComponent = $allComponents | where { $_.name -eq 'Microsoft-Windows-Setup' }
    $windowsShellSetupComponent = $allComponents | where { ($_.name -eq 'Microsoft-Windows-Shell-Setup') -and ($_.ProductKey -ne $null)}

    if ([string]::IsNullOrEmpty($productKey) -eq $true)
    {
      Write-Verbose "Removing product key from unattend file ..."
      $windowsSetupComponent.UserData.RemoveChild($windowsSetupComponent.UserData['ProductKey']) | Out-Null
      $windowsShellSetupComponent.RemoveChild($windowsShellSetupComponent['ProductKey']) | Out-Null
    }
    else
    {
      Write-Verbose "Setting up product key in unattend file ..."
      $windowsSetupComponent.UserData.ProductKey.Key = $productKey
      $windowsShellSetupComponent.ProductKey = $productKey
    }

    $unattendXml.Save($destinationFile)
  }
  catch
  {
    Write-Verbose $_.Exception
    $exceptionMessage = $_.Exception.Message
    throw "Error while trying to configure unattend file in vhd mounted at '${vhdMountLetter}:\': ${exceptionMessage}"
  }
}
