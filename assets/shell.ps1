Import-Module A:\glazier.psm1

Import-Module -DisableNameChecking 'A:\common\qemu-img-tools.psm1'
Import-Module -DisableNameChecking 'A:\common\openstack-tools.psm1'
Import-Module -DisableNameChecking 'A:\common\glazier-hostutils.psm1'
Import-Module -DisableNameChecking 'A:\common\glazier-profile-tools.psm1'

if ((Verify-QemuImg) -eq $false)
{
  Install-QemuImg -Verbose
}

if (!(Verify-PythonClientsInstallation))
{
  Install-PythonClients -Verbose
}

echo @"

 To create a new qcow2 image with a profile loaded by 'create-glazier', run the following:
  New-Image -Name "my-windows-image" -GlazierProfilePath "myprofile"

 To upload and install the image to OpenStack:
  Initialize-Image -Qcow2ImagePath "c:\workspace\<qcow2 filename>" -ImageName "my-windows-image"

Welcome to glazier!

The available profiles you can use are: $((Get-Profiles | Select -ExpandProperty Name) -join ", ")
"@

