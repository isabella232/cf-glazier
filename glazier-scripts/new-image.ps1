function New-Image {
  <#
  .SYNOPSIS
      Glazier create-image commandlet
  .DESCRIPTION
      Creates a Windows Server 2012 R2 qcow2 image that is ready to be booted for installation on OpenStack.
  .PARAMETER name
      A name for the image you want to create
  .NOTES
      Author: Hewlett Packard Development Company
      Date:   April 8, 2015
  .EXAMPLE
  Create-Image -Name "Windows 2012 R2 Core"
  #>
  [CmdletBinding()]
  param(
    [string]$Name
  )

}
