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


$name = 'surub'
$glazierProfile = 'c:\Users\Administrator\code\cf-glazier-profiles\mssql2012'
$windowsISOMountPath="c:\assets\winiso"
$virtIOPath="c:\assets\virtio"
$workspace = "d:\workspace"

New-Image -Name $name -GlazierProfile $glazierProfile -WindowsISOMountPath $WindowsISOMountPath -VirtIOPath $virtIOPath -Verbose -Workspace $workspace


# ************************************************************
# ****************************** STEP3 - CREATE IMAGE
# ************************************************************

$env:OS_REGION_NAME = "region-b.geo-1"
$env:OS_TENANT_ID = "10990308817909"
$env:OS_PASSWORD = "password1234!"
$env:OS_AUTH_URL = "https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/"
$env:OS_USERNAME = "viovanov"
$env:OS_TENANT_NAME = "Hewlettpackard6525"

$imageName = "surub"
$qcow2source = "d:\workspace\sticla20150419035849.qcow2"
$osKeyName = "vlad-key"
$osSecurityGroup = "default"
$osNetworkId = "c62508f5-b5a7-4e7e-b9ea-c9b69ac60bbe"
$osFlavor = "standard.2xlarge"


Initialize-Image -Verbose -Qcow2ImagePath $qcow2source -ImageName $imageName -OpenStackKeyName $osKeyName -OpenStackSecurityGroup $osSecurityGroup -OpenStackNetworkId $osNetworkId -OpenStackFlavor $osFlavor

 
# ************************************************************
# ****************************** OTHER STUFF
# ************************************************************


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
