$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir './common/utils.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/glazier-profile-tools.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/openstack-tools.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './common/qemu-img-tools.psm1')
Import-Module (Join-Path $currentDir './glazier.psm1')

$myProfile = Get-GlazierProfile '.\test\myprofile'

if ((Verify-QemuImg) -eq $false)
{
  Install-QemuImg
}


$name = 'pelerinul'
$glazierProfile = '.\test\myprofile'
$wimPath="C:\code\cf-windea-image-creation\assets\9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9\sources\install.wim"
$virtIOPath="C:\code\cf-windea-image-creation\assets\virtio-win-0.1-81"

New-Image -Name $name -GlazierProfile $glazierProfile -WimPath $wimPath -VirtIOPath $virtIOPath -Verbose
