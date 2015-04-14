
function Get-GlazierProfile{[CmdletBinding()]param($glazierProfilePath)
  if ((Test-Path $glazierProfilePath) -eq $false)
  {
    throw "Glazier profile path '${glazierProfilePath}' does not exist."
  }

  $files = 'features.csv', 'resources.csv', 'specialize\specialize.ps1', 'specialize\tools.csv'

  foreach ($file in $files)
  {
    $fullPath = Join-Path $glazierProfilePath $file

    if ((Test-Path $fullPath) -eq $false)
    {
      throw "${file} not found in profile directory '${glazierProfilePath}'"
    }
    else
    {
      Write-Verbose "Ok, '${file}' found in profile directory '${glazierProfilePath}'"
    }
  }

  $result = New-Object PSObject
  $result | Add-Member -MemberType 'NoteProperty' -Name 'Path' -value $glazierProfilePath
  $result | Add-Member -MemberType 'NoteProperty' -Name 'FeaturesCSVFile' -value (Join-Path $glazierProfilePath 'features.csv')
  $result | Add-Member -MemberType 'NoteProperty' -Name 'ResourcesCSVFile' -value (Join-Path $glazierProfilePath 'resources.csv')
  $result | Add-Member -MemberType 'NoteProperty' -Name 'SpecializeScriptFile' -value (Join-Path $glazierProfilePath 'specialize\specialize.ps1')
  $result | Add-Member -MemberType 'NoteProperty' -Name 'SpecializeToolsCSVFile' -value (Join-Path $glazierProfilePath 'specialize\tools.csv')

  return $result
}
