$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
Import-Module -DisableNameChecking (Join-Path $currentDir './utils.psm1')

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
  
  $result | Add-Member -MemberType 'NoteProperty' -Name 'Name' -value (Split-Path -Leaf $glazierProfilePath)
  $result | Add-Member -MemberType 'NoteProperty' -Name 'Path' -value $glazierProfilePath
  $result | Add-Member -MemberType 'NoteProperty' -Name 'FeaturesCSVFile' -value (Join-Path $glazierProfilePath 'features.csv')
  $result | Add-Member -MemberType 'NoteProperty' -Name 'ResourcesCSVFile' -value (Join-Path $glazierProfilePath 'resources.csv')
  $result | Add-Member -MemberType 'NoteProperty' -Name 'SpecializeScriptFile' -value (Join-Path $glazierProfilePath 'specialize\specialize.ps1')
  $result | Add-Member -MemberType 'NoteProperty' -Name 'SpecializeToolsCSVFile' -value (Join-Path $glazierProfilePath 'specialize\tools.csv')

  return $result
}

function Download-GlazierProfileResources{[CmdletBinding()]param($glazierProfile, $rootPath)
  $csv = Import-Csv $glazierProfile.ResourcesCSVFile

  Foreach ($line in $csv)
  {
    $url = $line.uri
    $destination = (Join-Path $rootPath $line.path)
    $destinationDir = Split-Path $destination

    mkdir $destinationDir -ErrorAction "SilentlyContinue" | Out-Null
    Download-File-With-Retry $url $destination
  }
}

function Get-Profiles{[CmdletBinding()]param()
  Get-ChildItem A:\profiles | ?{ $_.PSIsContainer} | Select-Object Name
}

