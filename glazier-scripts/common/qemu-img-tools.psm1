$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir './utils.psm1')

$qemuDir = Join-Path $env:HOMEDRIVE 'qemu'
$qemuBin = Join-Path $qemuDir 'qemu-img.exe'

function Verify-QemuImg()
{
  return (Test-Path $qemuBin)
}

function Install-QemuImg()
{
  $qemuUrl = Get-Dependency 'qemu-img'
  Clean-Dir $qemuDir
  Download-File $qemuUrl $qemuBin
}

function Convert-VHDToQCOW2($sourceVhd, $destinationQcow2)
{
  Write-Verbose "Converting vhd '${source}' to qcow2 '${destination}' ..."

  $convertProcess = Start-Process -Wait -PassThru -NoNewWindow $qemuBin "convert -O qcow2 '${sourceVhd}' '${destinationQcow2}'"

  if ($convertProcess.ExitCode -ne 0)
  {
    throw 'Converting vhd to qcow2 failed.'
  }
  else
  {
    Write-Verbose "vhd converted to qcow2 successfully."
  }
}
