$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir './common/utils.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/glazier-profile-tools.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/openstack-tools.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/qemu-img-tools.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/imaging-tools.psm1')

function New-Image {
  <#
  .SYNOPSIS
      Glazier create-image commandlet
  .DESCRIPTION
      Creates a Windows Server 2012 R2 qcow2 image that is ready to be booted for installation on OpenStack.
  .PARAMETER name
      A name for the image you want to create
  .NOTES
      Author: Hewlett-Packard Development Company
      Date:   April 8, 2015
  .EXAMPLE
  Create-Image -Name "Windows 2012 R2 Core"
  #>
  [CmdletBinding()]
  param(
    [string]$Name,
    [string]$GlazierProfilePath,
    [string]$WimPath='e:\sources\install.wim',
    [string]$VirtIOPath='f:\',
    [int]$SizeInBytes=25000,
    [string]$Workspace='c:\workspace',
    [switch]$CleanupWhenDone=$true,
    [string]$ProductKey=''
  )

  $isVerbose = [bool]$PSBoundParameters["Verbose"]
  $PSDefaultParameterValues = @{"*:Verbose"=$isVerbose}

  # TODO: check for tooling

  $timestamp = Get-Date -f 'yyyyMMddHHmmss'

  $vhdMountLetter = $null

  # Prepare some variable names
  $qcow2FileName = "$(Convert-ImageNameToFileName $Name)${timestamp}.qcow2"
  Write-Verbose "qcow2 filename will be ${qcow2FileName}"
  $vhdFileName = "$(Convert-ImageNameToFileName $Name)${timestamp}.vhd"
  Write-Verbose "vhd filename will be ${vhdFileName}"
  $workDir = Join-Path $Workspace $timestamp
  Write-Verbose "Will be working in directory ${workDir}"
  $qcow2Path = Join-Path $Workspace $qcow2FileName
  Write-Verbose "Full qcow2 path will be ${qcow2Path}"
  $vhdPath = Join-Path $workDir $vhdFileName
  Write-Verbose "Full vhd path will be ${vhdPath}"

  try
  {
    Write-Output 'Checking to see if script is running with administrative privileges ...'
    Check-IsAdmin

    Write-Output 'Validating wim file ...'
    Validate-WindowsWIM $WIMPath

    Write-Output 'Getting profile information ...'
    $glazierProfile = Get-GlazierProfile $GlazierProfilePath

    # Make sure we have a clean working directory
    Write-Output 'Cleaning up work directory ...'
    Clean-Dir $workDir

    Write-Output 'Creating and mounting vhd ...'
    CreateAndMount-VHDImage $vhdPath $SizeInBytes ([ref]$vhdMountLetter)

    Write-Output 'Applying wim to vhd ...'
    Apply-Image $WIMPath $vhdMountLetter

    Write-Output 'Setting up tools for the unattended install ...'
    Add-UnattendScripts $vhdMountLetter

    Write-Output 'Adding glazier profile to image ...'
    Add-GlazierProfile $vhdMountLetter $glazierProfile

    # TODO: add glazier resources as well, no need to boot the VM once more the first time we create the image

    Write-Output 'Adding VirtIO drivers to vhd ...'
    Add-VirtIODriversToImage $vhdMountLetter $VirtIOPath

    Write-Output 'Making vhd bootable ...'
    Create-BCDBootConfig $vhdMountLetter

    Write-Output 'Configuring Windows features ...'
    Set-DesiredFeatureStateInImage $vhdMountLetter $glazierProfile.FeaturesCSVFile $wimPath

    Write-Output 'Setting up unattend file ...'
    Add-UnattendXml $vhdMountLetter $ProductKey

    Write-Output 'Dismounting vhd ...'
    Dismount-VHDImage $vhdPath

    Write-Output 'Converting vhd to qcow2 ...'
    Convert-VHDToQCOW2 $vhdPath $qcow2Path
  }
  catch
  {
    $errorMessage = $_.Exception.Message
    $performConversionToQCOW2 = $false
    Write-Host -ForegroundColor Red "${errorMessage}"

    try
    {
      Write-Output 'Dismounting vhd ...'
      Dismount-VHDImage $vhdPath
    }
    catch
    {
      $errorMessage = $_.Exception.Message
      Write-Warning "Failed to dismount vhd (it must have already happened): ${errorMessage}"
    }
  }
  finally
  {
    if ($CleanupWhenDone -eq $true)
    {
      Write-Output 'Cleaning up work directory ...'
      rm -Recurse -Force -Confirm:$false $workDir -ErrorAction SilentlyContinue
    }
  }
}

function Initialize-Image {
  <#
  .SYNOPSIS
      Glazier Setup-Image commandlet
  .DESCRIPTION
      If needed, uploads a Windows 2012 R2 qcow2 image created using
      Create-Image, then boots it using Nova
  .PARAMETER ImagePath
      Path to a qcow2 image created using Create-Image
  .NOTES
      Author: Hewlett-Packard Development Company
      Date:   April 8, 2015
  .EXAMPLE
  Create-Image -Name "Windows 2012 R2 Core"
  #>
  [CmdletBinding()]
  param(
    [string]$Qcow2ImagePath,
    [string]$ImageName,
    [string]$OpenStackKeyName,
    [string]$OpenStackSecurityGroup,
    [string]$OpenStackNetworkId
  )

  $tempVMName = "${ImageName}-glazier-temp-instance-DO-NOT-USE"
  $tempImageName = "{ImageName}-glazier-temp-image-DO-NOT-USE"

  # TODO: load openrc info and validate it

  try
  {
    Write-Output "Creating temporary image ..."
    Create-Image $tempImageName $Qcow2ImagePath

    Write-Output "Booting temporary instance ..."
    Boot-VM $tempVMName $tempImageName $OpenStackKeyName $OpenStackSecurityGroup $OpenStackNetworkId

    Write-Output "Waiting for temporary instance to finish installation and shut down ..."
    WaitFor-VMShutdown $tempVMName

    Write-Output "Creating final image ..."
    Create-VMSnapshot $tempVMName $ImageName

    # TODO: set metadata
  }
  finally
  {
    try
    {
      Write-Output "Deleting temp instance ..."
      Delete-VMInstance $tempVMName
    }
    catch
    {
      $errorMessage = $_.Exception.Message
      Write-Warning "Failed to delete temp instance '${tempVMName}' (it probably doesn't exist): ${errorMessage}"
    }

    try
    {
      Write-Output "Deleting temp image ..."
      Delete-Image $tempImageName
    }
    catch
    {
      $errorMessage = $_.Exception.Message
      Write-Warning "Failed to delete temp image '${tempImageName}' (the image probably doesn't exist): ${errorMessage}"
    }
  }
}

function Push-Resources {
  <#
  .SYNOPSIS
      Glazier Push-Resources commandlet
  .DESCRIPTION
      Uploads resources for a glazier profile to an existing Windows Server 2012 R2 image that is available on OpenStack glance
  .PARAMETER GlazierProfilePath
      Path to the glazier profile directory
  .PARAMETER VmName
      Name of the VM to boot
  .PARAMETER KeyName
      Key name of ssh keypair
  .PARAMETER SecurityGroup
      Comma separated list of security group names
  .PARAMETER NetworkId
      UUID of the network
  .PARAMETER Image
      Name or ID of the image used to boot the VM
  .PARAMETER SnapshotImageName
      Name of Snapshot to be created
  .PARAMETER Flavor
      Name or ID of the flavor
  .PARAMETER HttpProxy
      Http host address proxy used for downloading files
  .PARAMETER HttpsProxy
      Https host address for proxy used for downloading files
  .NOTES
      Author: Hewlett-Packard Development Company
      Date:   April 8, 2015
  .EXAMPLE
  Push-Resources -GlazierProfilePath c:\myprofile -VmName Win2012 -KeyName private-ssh-key -SecurityGroup security-group -NetworkId uuid -Image uuid -SnapshotImageName win-snapshot -Flavor standard.medium
  #>
[CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$GlazierProfilePath,
    [Parameter(Mandatory=$true)]
    [string]$VmName,
    [Parameter(Mandatory=$true)]
    [string]$KeyName,
    [Parameter(Mandatory=$true)]
    [string]$SecurityGroup,
    [Parameter(Mandatory=$true)]
    [string]$NetworkId,
    [Parameter(Mandatory=$true)]
    [string]$Image,
    [Parameter(Mandatory=$true)]
    [string]$SnapshotImageName,
    [Parameter(Mandatory=$true)]
    [string]$Flavor,
    [string]$HttpProxy=$null,
    [string]$HttpsProxy=$null
  )

 try{
    $glazierProfile = Get-GlazierProfile $GlazierProfilePath
    Write-Verbose "Generating user-data script"
    $stringBuilder = New-Object System.Text.StringBuilder
    $stringBuilder.AppendLine("#ps1")
    $stringBuilder.AppendLine(@'
function Download-File{[CmdletBinding()]param($url, $targetFile, $proxy)
  Write-Verbose "Downloading '${url}' to '${targetFile}'"
  $uri = New-Object "System.Uri" "$url"
  $request = [System.Net.HttpWebRequest]::Create($uri)
  if($proxy -ne $null)
  {
    $request.Proxy = $proxy
  }
  $request.set_Timeout(15000) #15 second timeout
  $response = $request.GetResponse()
  $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
  $responseStream = $response.GetResponseStream()
  $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
  $buffer = new-object byte[] 10KB
  $count = $responseStream.Read($buffer,0,$buffer.length)
  $downloadedBytes = $count
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  while ($count -gt 0)
  {
     $targetStream.Write($buffer, 0, $count)
     $count = $responseStream.Read($buffer,0,$buffer.length)
     $downloadedBytes = $downloadedBytes + $count

     if ($sw.Elapsed.TotalMilliseconds -ge 500) {
       $activity = "Downloading file '$($url.split('/') | Select -Last 1)'"
       $status = "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): "
       $percentComplete = ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
       Write-Progress -activity $activity -status $status -PercentComplete $percentComplete

       $sw.Reset();
       $sw.Start()
    }
  }

  Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'" -status "Done"
  $targetStream.Flush()
  $targetStream.Close()
  $targetStream.Dispose()
  $responseStream.Dispose()
}
'@)

    $stringBuilder.AppendLine("`$destDir = `$env:SystemDrive")
    $csv = Import-Csv $glazierProfile.ResourcesCSVFile
    $userData = [System.IO.Path]::GetTempFileName()
    if(![string]::IsNullOrEmpty($HttpProxy))
    {
      $stringBuilder.AppendLine("`$proxy = new-object System.Net.WebProxy -ArgumentList `"${HttpProxy}`"")
    }
    elseif (![string]::IsNullOrEmpty($HttpsProxy))
    {
      $stringBuilder.AppendLine("`$proxy = new-object System.Net.WebProxy -ArgumentList `"${HttpsProxy}`", 433")
    }
    else
    {
      $stringBuilder.AppendLine("`$proxy = `$null")
    }

    Foreach ($line in $csv)
    {
      $localFileName = [System.IO.Path]::GetFileNameWithoutExtension(($line.path -replace '[-_]',''))
      $stringBuilder.AppendLine("`$${localFileName}Path = Join-Path `$destDir `"$($line.path)`"")
      $stringBuilder.AppendLine("New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName(`$${localFileName}Path))")
      $stringBuilder.AppendLine("Download-File -url `"$($line.uri)`" -targetFile `$${localFileName}Path -proxy `$proxy")
    }

    $stringBuilder.AppendLine("shutdown /s /t 100")
    $stringBuilder.ToString() | Out-File $userData -Encoding ascii

    Boot-VM $VmName $Image $KeyName $SecurityGroup $NetworkId $Flavor $userData

    WaitFor-VMShutdown $VmName

    Write-Verbose "Creating VM Snapshot ${SnapshotImageName}"
    Create-VMSnapshot $VmName $SnapshotImageName

    # TODO: implement setting metadata for image
  }
  finally{
    If (Test-Path $userData){
	  Remove-Item $userData
    }
  }
}

Export-ModuleMember -Function 'Initialize-Image', 'Push-Resources', 'New-Image'
