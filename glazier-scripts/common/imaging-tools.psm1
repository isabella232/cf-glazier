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

function CreateAndMount-VHDImage{[CmdletBinding()]param($vhdPath, $vhdMountLetter, $sizeInBytes)
  $diskpartScriptPath = "${vhdPath}.diskpart"

  $diskPartScript = @"
create vdisk file="${vhdPath}" maximum=${sizeInBytes} type=expandable
attach vdisk
create partition primary
assign letter="${vhdMountLetter}"
format fs="ntfs" label="System" quick
"@

  $diskPartScript | Out-File -Encoding 'ASCII' $diskpartScriptPath

  $diskpartProcess = Start-Process -Wait -PassThru -NoNewWindow 'diskpart' "/s `"${diskpartScriptPath}`""

  if ($diskpartProcess.ExitCode -ne 0)
  {
    throw 'Creating and mounting vhd failed.'
  }
  else
  {
    Write-Verbose "VHD created and mounted successfully."
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






#
#
#
#
#
#
#
#
#function TransformXml($xsltPath, $inXmlPath, $outXmlPath, $xsltArgs)
#{
#    $xslt = New-Object System.Xml.Xsl.XslCompiledTransform($false)
#    $xsltSettings = New-Object System.Xml.Xsl.XsltSettings($false, $true)
#    $xslt.Load($xsltPath, $xsltSettings, (New-Object System.Xml.XmlUrlResolver))
#    $outXmlFile = New-Object System.IO.FileStream($outXmlPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
#    $argList = new-object System.Xml.Xsl.XsltArgumentList
#
#    foreach($k in $xsltArgs.Keys)
#    {
#        $argList.AddParam($k, "", $xsltArgs[$k])
#    }
#
#    $xslt.Transform($inXmlPath, $argList, $outXmlFile)
#    $outXmlFile.Close()
#}
#
#function GenerateUnattendXml($inUnattendXmlPath, $outUnattendXmlPath, $image, $productKey, $administratorPassword)
#{
#    $xsltArgs = @{}
#
#    $xsltArgs["processorArchitecture"] = ([string]$image.ImageArchitecture).ToLower()
#    $xsltArgs["imageName"] = $image.ImageName
#    $xsltArgs["versionMajor"] = $image.ImageVersion.Major
#    $xsltArgs["versionMinor"] = $image.ImageVersion.Minor
#    $xsltArgs["installationType"] = $image.ImageInstallationType
#    $xsltArgs["administratorPassword"] = $administratorPassword
#
#    if($productKey) {
#        $xsltArgs["productKey"] = $productKey
#    }
#
#    TransformXml "$scriptPath\Unattend.xslt" $inUnattendXmlPath $outUnattendXmlPath $xsltArgs
#}
#
#function DetachVirtualDisk($vhdPath)
#{
#    try
#    {
#        $v = [WIMInterop.VirtualDisk]::OpenVirtualDisk($vhdPath)
#        $v.DetachVirtualDisk()
#    }
#    finally
#    {
#        $v.Close()
#    }
#}
#
#function GetDismVersion()
#{
#    return new-Object System.Version (gcm dism.exe).FileVersionInfo.ProductVersion
#}
#
#function CheckDismVersionForImage($image)
#{
#    $dismVersion = GetDismVersion
#    if ($image.ImageVersion.CompareTo($dismVersion) -gt 0)
#    {
#        Write-Warning "The installed version of DISM is older than the Windows image"
#    }
#}
#
#function ConvertVirtualDisk($vhdPath, $outPath, $format)
#{
#    Write-Output "Converting virtual disk image from $vhdPath to $outPath..."
#
#    $qemuFormat = $format.ToLower()
#
#    & cmd /c "${scriptPath}\bin\qemu-img.exe convert -O ${qemuFormat} ${vhdPath} ${outPath} 2>&1"
#    if($LASTEXITCODE) { throw "qemu-img failed to convert the virtual disk" }
#}
#
#function CopyUnattendResources($resourcesDir, $imageInstallationType)
#{
#    # Workaround to recognize the $resourcesDir drive. This seems a PowerShell bug
#    $drives = Get-PSDrive
#
#    if(!(Test-Path "$resourcesDir")) { $d = mkdir "$resourcesDir" }
#    copy -Recurse "$localResourcesDir\*" $resourcesDir
#
#    if ($imageInstallationType -eq "Server Core")
#    {
#        # Skip the wallpaper on server core
#        del -Force "$resourcesDir\Wallpaper.png"
#        del -Force "$resourcesDir\GPO.zip"
#    }
#}
#
#function DownloadCloudbaseInit($resourcesDir, $osArch)
#{
#    Write-Output "Downloading Cloudbase-Init..."
#
#    if($osArch -eq "AMD64")
#    {
#        $CloudbaseInitMsi = "CloudbaseInitSetup_Beta_x64.msi"
#    }
#    else
#    {
#        $CloudbaseInitMsi = "CloudbaseInitSetup_Beta_x86.msi"
#    }
#
#    $CloudbaseInitMsiPath = "$resourcesDir\CloudbaseInit.msi"
#    $CloudbaseInitMsiUrl = "https://www.cloudbase.it/downloads/$CloudbaseInitMsi"
#
#    (new-object System.Net.WebClient).DownloadFile($CloudbaseInitMsiUrl, $CloudbaseInitMsiPath)
#}
#
#function DownloadFile($url, $fileName, $resourcesDir)
#{
#  Write-Output "Downloading file from ${url} ..."
#
#  $file = Join-Path $resourcesDir $fileName
#
#  & cmd /c "${scriptPath}\bin\wget.exe --no-check-certificate --progress=dot -e dotbytes=100M ${url} -O ${file} 2>&1"
#
#  if($LASTEXITCODE) { throw "Failed to download file" }
#}
#
#function GenerateConfigFile($resourcesDir, $installUpdates)
#{
#    $configIniPath = "$resourcesDir\config.ini"
#    Import-Module "$localResourcesDir\ini.psm1"
#    Set-IniFileValue -Path $configIniPath -Section "DEFAULT" -Key "InstallUpdates" -Value $installUpdates
#}
#
#
#function SetProductKeyInImage($winImagePath, $productKey)
#{
#    Set-WindowsProductKey -Path $winImagePath -ProductKey $productKey
#}
#
#function EnableFeaturesInImage($winImagePath, $featureNames)
#{
#    if($featureNames)
#    {
#        $featuresCmdStr = "& cmd /c `"Dism.exe /image:${winImagePath} /Enable-Feature"
#        foreach($featureName in $featureNames)
#        {
#            $featuresCmdStr += " /FeatureName:$featureName"
#        }
#
#        # Prefer Dism over Enable-WindowsOptionalFeature due to better error reporting
#        Invoke-Expression "${featuresCmdStr} 2>&1`""
#        if ($LASTEXITCODE) { throw "Dism failed to enable features: $featureNames" }
#    }
#}
#
#
#
#function CheckEnablePowerShellInImage($winImagePath, $image)
#{
#    # Windows 2008 R2 Server Core dows not enable powershell by default
#    $v62 = new-Object System.Version 6, 2, 0, 0
#    if($image.ImageVersion.CompareTo($v62) -lt 0 -and $image.ImageInstallationType -eq "Server Core")
#    {
#        Write-Output "Enabling PowerShell in the Windows image"
#        $psFeatures = @("NetFx2-ServerCore", "MicrosoftWindowsPowerShell", `
#                        "NetFx2-ServerCore-WOW64", "MicrosoftWindowsPowerShell-WOW64")
#        EnableFeaturesInImage $winImagePath $psFeatures
#    }
#}
#
#
#function SetDotNetCWD()
#{
#    # Make sure the PowerShell and .Net CWD match
#    [Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
#}
#
#function GetPathWithoutExtension($path)
#{
#    return Join-Path ([System.IO.Path]::GetDirectoryName($path)) `
#                     ([System.IO.Path]::GetFileNameWithoutExtension($path))
#}
#
#function New-WindowsCloudImage()
#{
#    [CmdletBinding()]
#    param
#    (
#        [parameter(Mandatory=$true, ValueFromPipeline=$true)]
#        [string]$WimFilePath = "D:\Sources\install.wim",
#        [parameter(Mandatory=$true)]
#        [string]$ImageName,
#        [parameter(Mandatory=$true)]
#        [string]$VirtualDiskPath,
#        [parameter(Mandatory=$true)]
#        [Uint64]$SizeBytes,
#        [parameter(Mandatory=$false)]
#        [string]$ProductKey,
#        [parameter(Mandatory=$false)]
#        [ValidateSet("VHD", "QCow2", "VMDK", "RAW", ignorecase=$false)]
#        [string]$VirtualDiskFormat = "VHD",
#        [parameter(Mandatory=$false)]
#        [string]$VirtIOISOPath,
#        [parameter(Mandatory=$false)]
#        [switch]$InstallUpdates,
#        [parameter(Mandatory=$false)]
#        [string]$AdministratorPassword = "Pa`$`$w0rd",
#        [parameter(Mandatory=$false)]
#        [string]$UnattendXmlPath = "$scriptPath\UnattendTemplate.xml",
#        [parameter(Mandatory=$false)]
#        [hashtable]$ExtraResources = @{},
#        [parameter(Mandatory=$false)]
#        [string]$FeaturesFile,
#        [parameter(Mandatory=$false)]
#        [string]$WindowsSources
#    )
#    PROCESS
#    {
#        SetDotNetCWD
#        CheckIsAdmin
#
#        $image = Get-WimFileImagesInfo -WimFilePath $wimFilePath | where {$_.ImageName -eq $ImageName }
#        if(!$image) { throw 'Image "$ImageName" not found in WIM file "$WimFilePath"'}
#        CheckDismVersionForImage $image
#
#        if (Test-Path $VirtualDiskPath) { Remove-Item -Force $VirtualDiskPath }
#
#        if ($VirtualDiskFormat -in @("VHD", "VHDX"))
#        {
#            $VHDPath = $VirtualDiskPath
#        }
#        else
#        {
#            $VHDPath = "{0}.vhd" -f (GetPathWithoutExtension $VirtualDiskPath)
#            if (Test-Path $VHDPath) { Remove-Item -Force $VHDPath }
#        }
#
#        try
#        {
#            $driveLetter = CreateImageVirtualDisk $VHDPath $SizeBytes
#            $winImagePath = "${driveLetter}:\"
#            $resourcesDir = "${winImagePath}UnattendResources"
#            $unattedXmlPath = "${winImagePath}Unattend.xml"
#
#            GenerateUnattendXml $UnattendXmlPath $unattedXmlPath $image $ProductKey $AdministratorPassword
#            CopyUnattendResources $resourcesDir $image.ImageInstallationType
#            GenerateConfigFile $resourcesDir $installUpdates
#            DownloadCloudbaseInit $resourcesDir ([string]$image.ImageArchitecture)
#
#            foreach ($extraResource in $ExtraResources.GetEnumerator())
#            {
#              echo $extraResource.Key
#              DownloadFile $extraResource.Key $extraResource.Value $resourcesDir
#            }
#
#            ApplyImage $winImagePath $wimFilePath $image.ImageIndex
#            CreateBCDBootConfig $driveLetter
#
#            if ($FeaturesFile)
#            {
#              SetDesiredFeatureStateInImage $winImagePath $FeaturesFile $WindowsSources
#            }
#
#            CheckEnablePowerShellInImage $winImagePath $image
#
#            # Product key is applied by the unattend.xml
#            # Evaluate if it's the case to set the product key here as well
#            # which in case requires Dism /Set-Edition
#            #if($ProductKey)
#            #{
#            #    SetProductKeyInImage $winImagePath $ProductKey
#            #}
#
#            if($VirtIOISOPath)
#            {
#                AddVirtIODriversFromISO $winImagePath $image $VirtIOISOPath
#            }
#        }
#        finally
#        {
#            if (Test-Path $VHDPath)
#            {
#                DetachVirtualDisk $VHDPath
#            }
#        }
#
#        if ($VHDPath -ne $VirtualDiskPath)
#        {
#            ConvertVirtualDisk $VHDPath $VirtualDiskPath $VirtualDiskFormat
#            del -Force $VHDPath
#        }
#    }
#}
