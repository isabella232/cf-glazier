Import-Module A:\glazier.psm1

Import-Module -DisableNameChecking 'A:\common\qemu-img-tools.psm1'
Import-Module -DisableNameChecking 'A:\common\openstack-tools.psm1'
Import-Module -DisableNameChecking 'A:\common\glazier-hostutils.psm1'
Import-Module -DisableNameChecking 'A:\common\glazier-profile-tools.psm1'
Import-Module -DisableNameChecking 'A:\common\utils.psm1'

#this function tests that the provided network-id, flavor, key and security key exist
function Check-HostArgsOpenStackParams{[CmdletBinding()]param()
    $openStackKey = Get-HostArg "os-key-name"
    $openStackSecGroup = Get-HostArg "os-security-group"
    $openStackNetworkId = Get-HostArg "os-network-id"
    $openStackFlavor = Get-HostArg "os-flavor"

    Validate-OSParams $openStackKey $openStackSecGroup $openStackNetworkId $openStackFlavor
}

function Set-SystemTime{[CmdletBinding()]param()
  try
  {
    $dateResponse = (Invoke-WebRequest -UseBasicParsing $env:OS_AUTH_URL)
    $dateFromKeystone = $dateResponse.Headers["Date"]
  }
  catch
  {
    $dateFromKeystone = $_.Exception.Response.Headers["Date"]
  }
  
  Write-Host "Setting system date to '${dateFromKeystone}' (retrieved from keystone)"
  
  Set-Date -Date $dateFromKeystone
}


Set-SystemProxy -Verbose

if ((Verify-QemuImg) -eq $false)
{
  Install-QemuImg -Verbose
}

if (!(Verify-PythonClientsInstallation))
{
  Install-PythonClients -Verbose
}

Set-OpenStackVars
Check-HostArgsOpenStackParams
Set-SystemTime

echo @"

 To create a new qcow2 image with a profile loaded by 'create-glazier', run the following:
  New-Image -Name "my-windows-image" -GlazierProfilePath "myprofile"

 To upload and install the image to OpenStack:
  Initialize-Image -Qcow2ImagePath "c:\workspace\<qcow2 filename>" -ImageName "my-windows-image"

Welcome to glazier!

The available profiles you can use are: $((Get-Profiles | Select -ExpandProperty Name) -join ", ")
"@

