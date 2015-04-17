
Write-Output "Hello world"


$Host.UI.RawUI.WindowTitle = "Setting up print password script ..."
$originalPrintPasswordScript = Join-Path ${resourcesDir} 'printPassword.ps1'
$printPasswordScript = "$programFilesDir\Cloudbase Solutions\Cloudbase-Init\LocalScripts\printPassword.ps1"
Copy-Item -Force $originalPrintPasswordScript $printPasswordScript

$Host.UI.RawUI.WindowTitle = "Setting up first run script ..."
$originalFirstRunScript = Join-Path ${resourcesDir} 'firstRun.ps1'
$firstRunScript = "$programFilesDir\Cloudbase Solutions\Cloudbase-Init\LocalScripts\firstRun.ps1"
Copy-Item -Force $originalFirstRunScript $firstRunScript
