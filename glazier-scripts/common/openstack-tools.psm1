
$pythonDir = Join-Path $env:SYSTEMDRIVE 'Python27'
$pythonScriptDir = Join-Path $pythonDir 'Scripts'
$glanceBin = Join-Path $pythonScriptDir 'glance.exe'
$novaBin = Join-Path $pythonScriptDir 'nova.exe'


function Verify-PythonClientsInstallation{[CmdletBinding()]param()

}

function Install-PythonClients{[CmdletBinding()]param()
  # Download and install VC for Python from
  #wget 'http://www.microsoft.com/en-us/download/details.aspx?id=44266'
  #$installProcess = Start-Process -Wait -PassThru -NoNewWindow $novaBin "delete `"${vmName}`""
  #msiexec /quiet /i VCForPython27.msi

  #Download and install Python from
  #wget 'https://www.python.org/ftp/python/2.7.8/python-2.7.8.amd64.msi'
  #msiexec /quiet /i python-2.7.8.amd64.msi

  # Install easy_install by running this:
  #(Invoke-WebRequest https://bootstrap.pypa.io/ez_setup.py).Content | python -

  # Install pip
  # c:\Python27\Scripts\easy_install.exe pip

  # Install the clients:
  # c:\python27\scripts\pip.exe install python-novaclient
  # c:\python27\scripts\pip.exe install python-glanceclient
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
function Boot-VM{[CmdletBinding()]param($vmName, $imageName, $keyName, $securityGroup, $networkId)
  Write-Verbose "Booting VM '${vmName}' ..."

  $bootVMProcess = Start-Process -Wait -PassThru -NoNewWindow $novaBin "boot --flavor `"${flavor}`" --image `"${imageName}`" --key-name `"${keyName}`" --security-groups `"${securityGroup}`" --nic net-id=${networkId} `"${vmName}`""

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
