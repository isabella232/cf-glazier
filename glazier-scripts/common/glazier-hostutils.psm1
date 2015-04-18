
function Check-ArgsList{[CmdletBinding()]param()
  # gets the values from A:\args.csv
  $argslist = Import-csv A:\args.csv -Header @("name","value")

  # echo them out
  foreach ($line in $argslist)
  {
    echo "$($line.name) $($line.value)"
  }
}

# validates if the iso mounted is a windows installation iso
function Validate-WindowsISO{[CmdletBinding()]param()
  # get the $drivesletter for the windows iso
  $DriveLetter = Import-csv A:\driveletters.csv -Header @("drive","type") | Where-Object {$_.type -eq "windows"}

  $FullPath = Join-Path $($DriveLetter.drive) "sources\install.wim"

  $FileExist = Test-Path $FullPath

  if ( $FileExist -eq $False ) { echo "The drive $DriveLetter is not a Windows installation iso" }
}

function Check-CACERT{[CmdletBinding()]param()
  # if A:\cacert exists, put it in env
  $FileExist = Test-Path A:\cacert

  if ( $FileExist -eq $True ) { set OS_CACERT A:\cacert }
}

