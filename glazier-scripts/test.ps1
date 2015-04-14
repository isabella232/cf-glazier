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

# Stable VirtIO
# http://alt.fedoraproject.org/pub/alt/virtio-win/stable/virtio-win-0.1-81.iso

$name = 'pelerinul'
$glazierProfile = '.\test\myprofile'
$wimPath="c:\assets\winiso\sources\install.wim"
$virtIOPath="c:\assets\virtio"

New-Image -Name $name -GlazierProfile $glazierProfile -WimPath $wimPath -VirtIOPath $virtIOPath -Verbose

#Download-File "http://alt.fedoraproject.org/pub/alt/virtio-win/stable/virtio-win-0.1-81.iso" "c:\tmp\virtio_.iso"

#
#$letter = CreateAndMount-VHDImage 'c:\workspace\pelerinul.vhd' 25000
#ls "${letter}:\"
#Clean-Dir '${letter}:\test'
