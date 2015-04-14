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
    [string]$ImagePath,
    [string]$ImageName,
    [string]$ImageId
  )
}

function Push-Resources {
  <#
  .SYNOPSIS
      Glazier Upload-Resources commandlet
  .DESCRIPTION
      Uploads resources for a glazier profile to an existing Windows Server 2012 R2 image that is available on OpenStack glance
  .PARAMETER GlazierProfile
      Array of paths to glazier profile directories
  .NOTES
      Author: Hewlett-Packard Development Company
      Date:   April 8, 2015
  .EXAMPLE
  Create-Image -Name "Windows 2012 R2 Core"
  #>
  [CmdletBinding()]
  param(
    [string]$GlazierProfile,
    [string]$ImageName,
    [string]$ImageId,
    [string]$HttpProxy,
    [string]$HttpsProxy
  )

}

Export-ModuleMember -Function 'Initialize-Image', 'Push-Resources', 'New-Image'
