$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Remove-Module glazier
Remove-Module glazier-profile-tools
Remove-Module openstack-tools
Remove-Module qemu-img-tools
Remove-Module imaging-tools
Remove-Module utils

Import-Module -DisableNameChecking (Join-Path $currentDir './common/utils.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/glazier-profile-tools.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/openstack-tools.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/qemu-img-tools.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/imaging-tools.psm1')
Import-Module (Join-Path $currentDir './glazier.psm1')

$myProfile = Get-GlazierProfile '.\test\myprofile'

if ((Verify-QemuImg) -eq $false)
{
  Install-QemuImg -Verbose
}

if (!(Verify-PythonClientsInstallation))
{
  Install-PythonClients -Verbose
}

# ************************************************************
# ****************************** STEP2 - CREATE QCOW2
# ************************************************************


$name = 'mssql2014'
$glazierProfile = "c:\users\stackato\code\cf-glazier-profiles\${name}"
$windowsISOMountPath="d:\"
$virtIOPath="c:\assets\virtio"
$workspace = "c:\workspace"

# ************************************************************
# ****************************** STEP3 - CREATE IMAGE
# ************************************************************

$env:OS_REGION_NAME = "regionOne"
$env:OS_TENANT_ID = "fa6960fa0a3e4ffc86504c02953b1987"
$env:OS_PASSWORD = "password"
$env:OS_AUTH_URL = "https://10.9.231.35:5000/v2.0"
$env:OS_USERNAME = "vlad"
$env:OS_TENANT_NAME = "vlad"
$env:OS_CACERT = "c:\assets\os_cacert.pem"

#$imageName = $name
$qcow2source = "c:\workspace\mssql201220150428090431.qcow2"
$osKeyName = "vlad-key"
$osSecurityGroup = "default"
$osNetworkId = "e8871d2b-da09-4ece-8785-530da230c6b8"
$osFlavor = "m1.medium"

#Initialize-Image -Verbose -Qcow2ImagePath $qcow2source -ImageName $imageName -OpenStackKeyName $osKeyName -OpenStackSecurityGroup $osSecurityGroup -OpenStackNetworkId $osNetworkId -OpenStackFlavor $osFlavor

New-Image -Name $name -GlazierProfile $glazierProfile -WindowsISOMountPath $WindowsISOMountPath -VirtIOPath $virtIOPath -Verbose -Workspace $workspace -OpenStackKeyName $osKeyName -OpenStackSecurityGroup $osSecurityGroup -OpenStackNetworkId $osNetworkId -OpenStackFlavor $osFlavor


# ************************************************************
# ****************************** OTHER STUFF
# ************************************************************

#Get-SwiftToGlanceUrl "glazier-images" "win kajs hdkjasd 8923 #dea" -Verbose
#Validate-SwiftExistence -Verbose


# Stable VirtIO
# http://alt.fedoraproject.org/pub/alt/virtio-win/stable/virtio-win-0.1-81.iso


#Download-File "http://alt.fedoraproject.org/pub/alt/virtio-win/stable/virtio-win-0.1-81.iso" "c:\tmp\virtio_.iso"
#
#$PSDefaultParameterValues = @{"*:Verbose"=$true}
#Install-PythonClients -Verbose

#
#$letter = CreateAndMount-VHDImage 'c:\workspace\pelerinul.vhd' 25000
#ls "${letter}:\"
#Clean-Dir '${letter}:\test'
