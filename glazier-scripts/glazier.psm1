$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

. (Join-Path $currentDir "new-image.ps1")
. (Join-Path $currentDir "initialize-image.ps1")
. (Join-Path $currentDir "push-resources.ps1")
