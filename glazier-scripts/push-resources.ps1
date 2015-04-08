function Push-Resources {
  <#
  .SYNOPSIS
      Glazier Upload-Resources commandlet
  .DESCRIPTION
      Uploads resources for a glazier profile to an existing Windows Server 2012 R2 image that is available on OpenStack glance
  .PARAMETER GlazierProfile
      Array of paths to glazier profile directories
  .NOTES
      Author: Hewlett Packard Development Company
      Date:   April 8, 2015
  .EXAMPLE
  Create-Image -Name "Windows 2012 R2 Core"
  #>
  [CmdletBinding()]
  param(
    [string]$GlazierProfile,
    [string]$ImageName,
    [string]$ImageId
  )

}
