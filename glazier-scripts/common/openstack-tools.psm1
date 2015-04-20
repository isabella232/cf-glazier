$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir './utils.psm1')

$pythonDir = Join-Path $env:SYSTEMDRIVE 'Python34'
$pythonScriptDir = Join-Path $pythonDir 'Scripts'
$glanceBin = Join-Path $pythonScriptDir 'glance.exe'
$novaBin = Join-Path $pythonScriptDir 'nova.exe'


function Verify-PythonClientsInstallation{[CmdletBinding()]param()
    return ((Check-NovaClient) -and (Check-GlanceClient))
}

function Install-PythonClients{[CmdletBinding()]param()
    Write-Output "Installing Python clients"
    Install-VCRedist
    Install-Python
    Install-EasyInstall
    Install-Pip
    Install-NovaClient
    Install-GlanceClient
    Write-Output "Done"
}

function Check-VCRedist{[CmdletBinding()]param()
    return ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | where DisplayName -like "*Visual C++ 2010*x64*") -ne $null)
}

function Install-VCRedist{[CmdletBinding()]param()
    if(Check-VCRedist)
    {
        Write-Output "VC++ 2010 Redistributable already installed"
        return
    }

    try
    {
        $vcInstaller = Join-Path $env:temp "vcredist_x64.exe"
        Write-Output "Downloading VC Redistributable ..."
        $vcRedistUrl = Get-Dependency "vc-redist"
        Download-File $vcRedistUrl $vcInstaller
        $installProcess = Start-Process -Wait -PassThru -NoNewWindow $vcInstaller "/q /norestart"
        if (($installProcess.ExitCode -ne 0) -or !(Check-VCRedist))
        {
            throw 'Installing VC++ 2010 Redist failed.'
        }

        Write-Output "Finished installing VC++ Redistributable"
    }
    finally
    {
        If (Test-Path $vcInstaller){
	      Remove-Item $vcInstaller
        }
    }
}

function Check-Python{[CmdletBinding()]param()
    return (Test-Path (Join-Path $pythonDir "python.exe"))
}

function Install-Python{[CmdletBinding()]param()
    if(Check-Python)
    {
        Write-Output "Python already installed"
        return
    }

    try
    {
        Write-Output "Downloading Python ..."
        $pythonUrl = Get-Dependency "python"
        $pythonInstaller = Join-Path $env:temp "Python.msi"
        Download-File $pythonUrl $pythonInstaller
        Write-Output "Installing Python ..."
        $installProcess = Start-Process -Wait -PassThru -NoNewWindow msiexec "/quiet /i ${pythonInstaller} TARGETDIR=`"${pythonDir}`""
        if (($installProcess.ExitCode -ne 0) -or !(Check-Python))
        {
            throw 'Installing Python failed.'
        }

        Write-Output "Finished installing Python"
    }
    finally
    {
        If (Test-Path $pythonInstaller){
          Remove-Item $pythonInstaller -Force
        }
    }
}

function Check-EasyInstall{[CmdletBinding()]param()
    return (Test-Path (Join-Path $pythonScriptDir "easy_install.exe"))
}

function Install-EasyInstall{[CmdletBinding()]param()
    if(Check-EasyInstall)
    {
        Write-Output "EasyInstall already installed"
        return
    }

    $env:Path = $env:Path + ";${pythonDir};${pythonScriptDir}"

    Write-Output "Installing easy_install ..."

    $easyInstallUrl = Get-Dependency "easy-install"

    (Invoke-WebRequest $easyInstallUrl).Content | python -
    if(!(Check-EasyInstall))
    {
        throw "EasyInstall installation failed"
    }

    Write-Output "Finished installing EasyInstall"
}

function Check-Pip{[CmdletBinding()]param()
    return (Test-Path (Join-Path $pythonScriptDir "pip.exe"))
}

function Install-Pip{[CmdletBinding()]param()
    if(Check-Pip)
    {
        Write-Output "Pip already installed"
        return
    }
    Write-Output "Installing pip ..."
    $installProcess = Start-Process -Wait -PassThru -NoNewWindow "${pythonScriptDir}\easy_install.exe" "pip"
    if (($installProcess.ExitCode -ne 0) -or !(Check-Pip))
    {
        throw 'Installing pip for Python failed.'
    }

    Write-Output "Finished installing pip"
}

function Check-NovaClient{[CmdletBinding()]param()
    return (Test-Path $novaBin)
}

function Install-NovaClient{[CmdletBinding()]param()
    if(Check-NovaClient)
    {
        Write-Output "NovaClient already installed"
        return
    }
    Write-Output "Installing python-novaclient ..."
    $novaVersion = Get-Dependency "python-novaclient-version"
    $installProcess = Start-Process -Wait -PassThru -NoNewWindow "${pythonScriptDir}\pip.exe" "install python-novaclient==${novaVersion}"
    if (($installProcess.ExitCode -ne 0) -or !(Check-NovaClient))
    {
        throw 'Installing nova client failed.'
    }

    Write-Output "Finished installing nova client"
}

function Check-GlanceClient{[CmdletBinding()]param()
    return (Test-Path $glanceBin)
}

function Install-GlanceClient{[CmdletBinding()]param()
    if(Check-GlanceClient)
    {
        Write-Output "GlanceClient already installed"
        return
    }
    Write-Output "Installing python-glanceclient ..."
    $glanceVersion = Get-Dependency "python-glanceclient-version"
    $installProcess = Start-Process -Wait -PassThru -NoNewWindow "${pythonScriptDir}\pip.exe" "install python-glanceclient==${glanceVersion}"
    if (($installProcess.ExitCode -ne 0) -or !(Check-GlanceClient))
    {
        throw 'Installing glance client failed.'
    }

    Write-Output "Finished installing glance client"
}


# Terminate a VM instance
function Delete-VMInstance{[CmdletBinding()]param($vmName)
  Write-Verbose "Deleting instance '${vmName}' ..."

  $deleteVMProcess = Start-Process -Wait -PassThru -NoNewWindow $novaBin "delete `"${vmName}`""

  if ($deleteVMProcess.ExitCode -ne 0)
  {
    throw 'Deleting VM failed.'
  }
  else
  {
    Write-Verbose "VM deleted successfully."
  }
}

# Delete images
function Delete-Image{[CmdletBinding()]param($imageName)
  Write-Verbose "Deleting image '${imageName}' ..."

  $deleteImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "image-delete `"${imageName}`""

  if ($deleteImageProcess.ExitCode -ne 0)
  {
    throw 'Deleting image failed.'
  }
  else
  {
    Write-Verbose "Image deleted successfully."
  }
}

# Create a new image from the VM that installed Windows
function Create-VMSnapshot{[CmdletBinding()]param($vmName, $imageName)
  Write-Verbose "Creating image '${imageName}' based on instance ..."

  $createImageProcess = Start-Process -Wait -PassThru -NoNewWindow $novaBin "image-create --poll `"${vmName}`" `"${imageName}`""

  if ($createImageProcess.ExitCode -ne 0)
  {
    throw 'Create image from VM failed.'
  }
  else
  {
    Write-Verbose "Image created successfully."
  }
}

# Wait for the instance to be shut down
function WaitFor-VMShutdown{[CmdletBinding()]param($vmName)
  $instanceOff = $false
  while ($instanceOff -eq $false)
  {
    Write-Output "Sleeping for 1 minute ..."
    Start-Sleep -s 60
    $vmStatus = (& $novaBin show "${vmName}" --minimal | sls -pattern "^\| status\s+\|\s+(?<state>\w+)" | select -expand Matches | foreach {$_.groups["state"].value})

    if (${vmStatus} -eq 'ERROR')
    {
      throw 'VM is in an error state.'
    }

    Write-Output "Instance status is '${vmStatus}'"
    $instanceOff = ($vmStatus -eq 'SHUTOFF')
  }
}

# Boot a VM using the created image (it will install Windows unattended)
function Boot-VM{[CmdletBinding()]param($vmName, $imageName, $keyName, $securityGroup, $networkId, $flavor, $userData)
  Write-Verbose "Booting VM '${vmName}' ..."

  if($userData -ne $null)
  {
    $userDataStr = "--user-data `"${userData}`""
  }
  else
  {
    $userDataStr = ""
  }

  $bootVMProcess = Start-Process -Wait -PassThru -NoNewWindow $novaBin "boot --flavor `"${flavor}`" --image `"${imageName}`" --key-name `"${keyName}`" --security-groups `"${securityGroup}`" ${userDataStr} --nic net-id=${networkId} `"${vmName}`""

  if ($bootVMProcess.ExitCode -ne 0)
  {
    throw 'Booting VM failed.'
  }
  else
  {
    Write-Verbose "VM booted successfully."
  }
}

# Update an image with the specified property
function Update-ImageProperty{[CmdletBinding()]param($imageName, $propertyName, $propertyValue)
  Write-Verbose "Updating property '${propertyName}' for image '${imageName}' using glance ..."
  $updateImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "image-update --property ${propertyName}=${propertyValue} `"${imageName}`""
  if ($updateImageProcess.ExitCode -ne 0)
  {
    throw 'Update image property failed.'
  }
  else
  {
    Write-Verbose "Update image property was successful."
  }
}

# Create an image based on the generated qcow2
function Create-Image{[CmdletBinding()]param($imageName, $localQCOW2Image)
  Write-Verbose "Creating image '${imageName}' using glance ..."
  $createImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "image-create --progress --disk-format qcow2 --container-format bare --file `"${localQCOW2Image}`" --name `"${imageName}`""
  if ($createImageProcess.ExitCode -ne 0)
  {
    throw 'Create image failed.'
  }
  else
  {
    Write-Verbose "Create image was successful."
  }
}

# List API versions, in order to check env vars
function Validate-OSEnvVars{[CmdletBinding()]param()
  Write-Verbose "Checking OS_* env vars ..."

  if ([string]::IsNullOrWhitespace($env:OS_REGION_NAME)) { throw 'OS_REGION_NAME missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_TENANT_ID)) { throw 'OS_TENANT_ID missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_PASSWORD)) { throw 'OS_PASSWORD missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_AUTH_URL)) { throw 'OS_AUTH_URL missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_USERNAME)) { throw 'OS_USERNAME missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_TENANT_NAME)) { throw 'OS_TENANT_NAME missing!' }
}
