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
      Author: Hewlett Packard Development Company
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
