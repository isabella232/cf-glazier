$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir './utils.psm1')

$pythonDir = Join-Path $env:HOMEDRIVE 'Python27'
$pythonScriptDir = Join-Path $pythonDir 'Scripts'
$glanceBin = Join-Path $pythonScriptDir 'glance.exe'
$novaBin = Join-Path $pythonScriptDir 'nova.exe'


function Verify-PythonClientsInstallation{[CmdletBinding()]param()

}

function Install-PythonClients{[CmdletBinding()]param()

  $vcforPythonInstaller = Join-Path $env:temp "VCForPython27.msi"
  $pythonInstaller = Join-Path $env:temp "Python.msi"

  try
  {

  # Download and install VC for Python
  Write-Output "Downloading VC for Python ..."
  Download-File 'http://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi' $vcforPythonInstaller
  Write-Output "Installing VC for Python ..."
  $installProcess = Start-Process -Wait -PassThru -NoNewWindow msiexec "/quiet /i ${vcforPythonInstaller}"
  if ($installProcess.ExitCode -ne 0)
  {
    throw 'Installing VC for Python failed.'
  }
  
  #Download and install Python
  Write-Output "Downloading Python ..."
  Download-File 'https://www.python.org/ftp/python/2.7.8/python-2.7.8.amd64.msi' $pythonInstaller
  Write-Output "Installing Python ..."
  $installProcess = Start-Process -Wait -PassThru -NoNewWindow msiexec "/quiet /i ${pythonInstaller} TARGETDIR=`"${pythonDir}`""
  if ($installProcess.ExitCode -ne 0)
  {
    throw 'Installing Python failed.'
  }

  $env:Path = $env:Path + ";${pythonDir};${pythonScriptDir}"

  # Install easy_install
  Write-Output "Installing easy_install ..."  
  (Invoke-WebRequest https://bootstrap.pypa.io/ez_setup.py).Content | python -

  # Install pip
  Write-Output "Installing pip ..."
  $installProcess = Start-Process -Wait -PassThru -NoNewWindow "${pythonScriptDir}\easy_install.exe" "pip"
  if ($installProcess.ExitCode -ne 0)
  {
    throw 'Installing pip for Python failed.'
  }

  # Install the clients
  Write-Output "Installing python-novaclient ..."
  $installProcess = Start-Process -Wait -PassThru -NoNewWindow "${pythonScriptDir}\pip.exe" "install python-novaclient"
  if ($installProcess.ExitCode -ne 0)
  {
    throw 'Installing novaclient failed.'
  }

  Write-Output "Installing python-glanceclient ..."
  $installProcess = Start-Process -Wait -PassThru -NoNewWindow "${pythonScriptDir}\pip.exe" "install python-glanceclient"
  if ($installProcess.ExitCode -ne 0)
  {
    throw 'Installing glanceclient failed.'
  }
  Write-Output "Done"

  }
  finally
  {
    If (Test-Path $vcforPythonInstaller){
	  Remove-Item $vcforPythonInstaller
    }   
    If (Test-Path $pythonInstaller){
      Remove-Item $pythonInstaller -Force
    }
  }
}

function Check-OpenRCEnvVars{[CmdletBinding()]param()
  #OS_REGION_NAME=region-b.geo-1
  #OS_TENANT_ID=10990308817909
  #OS_PASSWORD=ecastravete
  #OS_AUTH_URL=https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/
  #OS_USERNAME=viovanov
  #OS_TENANT_NAME=Hewlettpackard6525
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
  Write-Verbose "Creating image '${baseCompleteImageName}' based on instance ..."

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
function UpdateImageProperty{[CmdletBinding()]param($imageName, $propertyName, $propertyValue)
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
function CreateImage{[CmdletBinding()]param($imageName, $localQCOW2Image)
  Write-Verbose "Creating image '${imageName}' using glance ..."
  $createImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "image-create --min-disk 20 --min-ram 2048 --disk-format qcow2 --container-format bare --file `"${localQCOW2Image}`" --name `"${imageName}`""
  if ($createImageProcess.ExitCode -ne 0)
  {
    throw 'Create image failed.'
  }
  else
  {
    Write-Verbose "Create image was successful."
  }
}
