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

# ************************************************************
# ****************************** STEP2 - CREATE QCOW2
# ************************************************************

#$name = 'pelerinul'
#$glazierProfile = '.\test\myprofile'
#$wimPath="c:\assets\winiso\sources\install.wim"
#$virtIOPath="c:\assets\virtio"

#New-Image -Name $name -GlazierProfile $glazierProfile -WimPath $wimPath -VirtIOPath $virtIOPath -Verbose

# ************************************************************
# ****************************** STEP3 - CREATE IMAGE
# ************************************************************

$env:OS_REGION_NAME = "region-b.geo-1"
$env:OS_TENANT_ID = "10990308817909"
$env:OS_PASSWORD = "password1234!"
$env:OS_AUTH_URL = "https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/"
$env:OS_USERNAME = "viovanov"
$env:OS_TENANT_NAME = "Hewlettpackard6525"

$imageName = "zugrav"
$qcow2source = "c:\workspace\pelerinul20150416132919.qcow2"
$osKeyName = "vlad-key"
$osSecurityGroup = "vlad-key"
$osNetworkId = "c62508f5-b5a7-4e7e-b9ea-c9b69ac60bbe"

Initialize-Image -Qcow2ImagePath $qcow2source -ImageName $imageName -OpenStackKeyName $osKeyName -OpenStackSecurityGroup $osSecurityGroup -OpenStackNetworkId $osNetworkId

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
