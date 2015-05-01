$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir './utils.psm1')

$pythonDir = Join-Path $env:SYSTEMDRIVE 'Python27'
$pythonScriptDir = Join-Path $pythonDir 'Scripts'
$glanceBin = Join-Path $pythonScriptDir 'glance.exe'
$novaBin = Join-Path $pythonScriptDir 'nova.exe'
$swiftBin = Join-Path $pythonScriptDir 'swift.exe'


function Get-InsecureFlag{[CmdletBinding()]param()
    If ( $env:OS_INSECURE -match "true" )
    {
        return '--insecure'
    }
    Else
    {
        return ''
    }
}

function Verify-PythonClientsInstallation{[CmdletBinding()]param()
  return ((Check-NovaClient) -and (Check-GlanceClient) -and (Check-SwiftClient))
}

function Install-PythonClients{[CmdletBinding()]param()
    Write-Output "Installing Python clients"
    Install-VCRedist
    Install-Python
    Install-EasyInstall
    Install-Pip
    Install-NovaClient
    Install-GlanceClient
    Install-SwiftClient
    Write-Output "Done"
}

function Check-VCRedist{[CmdletBinding()]param()
    return ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | where DisplayName -like "*Visual C++ 2008*x64*") -ne $null)
}

function Install-VCRedist{[CmdletBinding()]param()
    if(Check-VCRedist)
    {
        Write-Output "VC++ 2008 Redistributable already installed"
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
            throw 'Installing VC++ 2008 Redist failed.'
        }

        Write-Output "Finished installing VC++ 2008 Redistributable"
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

function Check-SwiftClient{[CmdletBinding()]param()
    return (Test-Path $swiftBin)
}

function Install-SwiftClient{[CmdletBinding()]param()
    if(Check-SwiftClient)
    {
        Write-Output "SwiftClient already installed"
        return
    }
    Write-Output "Installing python-swiftclient ..."
    $swiftVersion = Get-Dependency "python-swiftclient-version"
    $installProcess = Start-Process -Wait -PassThru -NoNewWindow "${pythonScriptDir}\pip.exe" "install python-swiftclient==${swiftVersion}"
    if (($installProcess.ExitCode -ne 0) -or !(Check-GlanceClient))
    {
        throw 'Installing swift client failed.'
    }

    Write-Output "Finished installing swift client"
}

function Create-SwiftContainer{[CmdletBinding()]param($container)
  Write-Verbose "Creating container '${container}' in swift ..."

  $createProcess = Start-Process -Wait -PassThru -NoNewWindow $swiftBin "$(Get-InsecureFlag) post ${container}"

  if ($createProcess.ExitCode -ne 0)
  {
    throw 'Creating swift container failed.'
  }
  else
  {
    Write-Verbose "[OK] Swift container created successfully."
  }
}

function Upload-Swift{[CmdletBinding()]param($localPath, $container, $remotePath)
  Write-Verbose "Uploading '${localPath}' to '${remotePath}' in container '${container}'"

  # Use a 100MB segment size
  $segmentSize = 1024 * 1024 * 100

  $uploadProcess = Start-Process -Wait -PassThru -NoNewWindow $swiftBin "$(Get-InsecureFlag) upload --segment-size ${segmentSize} --segment-threads 1 --object-name `"${remotePath}`" `"${container}`" `"${localPath}`""

  if ($uploadProcess.ExitCode -ne 0)
  {
    throw 'Uploading to swift failed.'
  }
  else
  {
    Write-Verbose "[OK] Upload successful."
  }
}

function Delete-SwiftContainer{[CmdletBinding()]param($container)
  Write-Verbose "Deleting container '${container}'"

  $deleteProcess = Start-Process -Wait -PassThru -NoNewWindow $swiftBin "$(Get-InsecureFlag) delete `"${container}`""

  if ($deleteProcess.ExitCode -ne 0)
  {
    throw 'Deleting from swift failed.'
  }
  else
  {
    Write-Verbose "[OK] Delete successful."
  }
}

function Get-SwiftToGlanceUrl{[CmdletBinding()]param($container, $object)
  [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
  $url = [UriBuilder]"${env:OS_AUTH_URL}"
  $url.Scheme = "swift"
  $url.Path = Join-Path $url.Path "${container}/${object}"
  $url.UserName = [System.Web.HttpUtility]::UrlEncode("${env:OS_TENANT_NAME}:${env:OS_USERNAME}")
  $url.Password = [System.Web.HttpUtility]::UrlEncode($env:OS_PASSWORD)

  return $url.Uri.AbsoluteUri.ToString()
}

function Download-Swift{[CmdletBinding()]param($container, $remotePath, $localPath)
  Write-Verbose "Downloading '${remotePath}' to '${localPath}' from container '${container}'"

  $downloadProcess = Start-Process -Wait -PassThru -NoNewWindow $swiftBin "$(Get-InsecureFlag) download --output `"${localPath}`" `"${container}`" `"${remotePath}`""

  if ($downloadProcess.ExitCode -ne 0)
  {
    throw 'Downloading from swift failed.'
  }
  else
  {
    Write-Verbose "[OK] Download successful."
  }
}

function Validate-SwiftExistence{[CmdletBinding()]param()
  try
  {
    # Do not use swift storage on HP Public Cloud
    if ($env:OS_AUTH_URL -like '*.hpcloudsvc.com:*')
    {
      return $false
    }

    if ([string]::IsNullOrWhitespace($env:OS_CACERT) -eq $false)
    {
      Import-509Certificate $env:OS_CACERT 'LocalMachine' 'Root'
    }

    Configure-SSLErrors

    $url = "${env:OS_AUTH_URL}/tokens"
    $body = "{`"auth`":{`"passwordCredentials`":{`"username`": `"${env:OS_USERNAME}`",`"password`": `"${env:OS_PASSWORD}`"},`"tenantId`": `"${env:OS_TENANT_ID}`"}}"
    $headers = @{"Content-Type"="application/json"}

    # Make the call
    $response = Invoke-WebRequest -UseBasicParsing -Uri $url -Method Post -Body $body -Headers $headers

    $jsonResponse = ConvertFrom-Json $response.Content
    $objectStore = ($jsonResponse.access.serviceCatalog | ? { $_.type -eq 'object-store'})

    if ($objectStore -eq $null)
    {
        return $false
    }

    $endpoint = ($objectStore.endpoints | ? {$_.region -eq $env:OS_REGION_NAME})

    if ($endpoint -eq $null)
    {
      return $false
    }

    Write-Verbose "Found the following swift url: $($endpoint.publicUrl)"
    return $true
  }
  catch
  {
    $errorMessage = $_.Exception.Message
    Write-Verbose "Error while trying to find a swift store: ${errorMessage}"
    return $false
  }
}

# Terminate a VM instance
function Delete-VMInstance{[CmdletBinding()]param($vmName)
  Write-Verbose "Deleting instance '${vmName}' ..."

  $deleteVMProcess = Start-Process -Wait -PassThru -NoNewWindow $novaBin "$(Get-InsecureFlag) delete `"${vmName}`""

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

  $deleteImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "$(Get-InsecureFlag) image-delete `"${imageName}`""

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

  $createImageProcess = Start-Process -Wait -PassThru -NoNewWindow $novaBin "$(Get-InsecureFlag) image-create --poll `"${vmName}`" `"${imageName}`""

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

  $isVerbose = [bool]$PSBoundParameters["Verbose"]
  $instanceOffCount = 0
  $instanceErrorCount = 0
  $instanceUnknownCount = 0

  while ($instanceOffCount -lt 3)
  {
    [Console]::Out.Write(".")

    Start-Sleep -s 60
    $vmStatus = (& $novaBin $(Get-InsecureFlag) show "${vmName}" --minimal | sls -pattern "^\| status\s+\|\s+(?<state>\w+)" | select -expand Matches | foreach {$_.groups["state"].value})

    if (${vmStatus} -eq 'ERROR')
    {
      $instanceErrorCount = $instanceErrorCount + 1
    }
    else
    {
      $instanceErrorCount = 0
    }

    if ([string]::IsNullOrWhitespace(${vmStatus}) -eq $true)
    {
      $vmStatus = "U"

      $instanceUnknownCount = $instanceUnknownCount + 1
    }
    else
    {
      $instanceUnknownCount = 0
    }

    if ($instanceErrorCount -gt 3)
    {
      Write-Output " Error"
      throw 'VM is in an error state.'
    }

    if ($instanceUnknownCount -gt 3)
    {
      Write-Output " Unknown"
      throw 'VM is in an unknown state.'
    }

    if ($isVerbose)
    {
      [Console]::Out.Write("$($vmStatus[0])")
    }

    if ($vmStatus -eq 'SHUTOFF')
    {
      $instanceOffCount = $instanceOffCount + 1
    }
    else
    {
      $instanceOffCount = 0
    }
  }

  Write-Output "Done"
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

  $bootVMProcess = Start-Process -Wait -PassThru -NoNewWindow $novaBin "$(Get-InsecureFlag) boot --flavor `"${flavor}`" --image `"${imageName}`" --key-name `"${keyName}`" --security-groups `"${securityGroup}`" ${userDataStr} --nic net-id=${networkId} `"${vmName}`""

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
  $updateImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "$(Get-InsecureFlag) image-update --property ${propertyName}=${propertyValue} `"${imageName}`""
  if ($updateImageProcess.ExitCode -ne 0)
  {
    throw 'Update image property failed.'
  }
  else
  {
    Write-Verbose "Update image property was successful."
  }
}

function Update-ImageInfo{[CmdletBinding()]param([string]$imageName, [int]$minDiskGB, [int]$minRamMB)
  Write-Verbose "Updating image '${imageName}' minimum requirements ..."
  $updateImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "$(Get-InsecureFlag) image-update --min-disk ${minDiskGB} --min-ram ${minRamMB} `"${imageName}`""
  if ($updateImageProcess.ExitCode -ne 0)
  {
    throw 'Update image info failed.'
  }
  else
  {
    Write-Verbose "Update image info was successful."
  }
}

# Create an image based on the generated qcow2
function Create-Image{[CmdletBinding()]param($imageName, $localQCOW2Image)
  Write-Verbose "Creating image '${imageName}' using glance ..."
  $createImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "$(Get-InsecureFlag) image-create --progress --disk-format qcow2 --container-format bare --file `"${localQCOW2Image}`" --name `"${imageName}`""
  if ($createImageProcess.ExitCode -ne 0)
  {
    throw 'Create image failed.'
  }
  else
  {
    Write-Verbose "Create image was successful."
  }
}

# Create an image based on a swift url
function Create-ImageFromSwift{[CmdletBinding()]param($imageName, $container, $object)
  try
  {
    $swiftObjectUrl = Get-SwiftToGlanceUrl $container $object
  }
  catch
  {
    $errorMessage = $_.Exception.Message
    throw "Could not generate a swift object url for glance: ${errorMessage}"
  }

  Write-Verbose "Creating image '${imageName}' using glance from swift source '${swiftObjectUrl}' ..."
  $createImageProcess = Start-Process -Wait -PassThru -NoNewWindow $glanceBin "$(Get-InsecureFlag) image-create --progress --disk-format qcow2 --container-format bare --location `"${swiftObjectUrl}`" --name `"${imageName}`""
  if ($createImageProcess.ExitCode -ne 0)
  {
    throw 'Create image from swift failed.'
  }
  else
  {
    Write-Verbose "Create image from swift was successful. Sleeping 1 minute ..."
    Start-Sleep -s 60
  }
}

# check OS_* specific env vars
function Validate-OSEnvVars{[CmdletBinding()]param()
  Write-Verbose "Checking OS_* env vars ..."

  if ([string]::IsNullOrWhitespace($env:OS_REGION_NAME)) { throw 'OS_REGION_NAME missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_TENANT_ID)) { throw 'OS_TENANT_ID missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_PASSWORD)) { throw 'OS_PASSWORD missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_AUTH_URL)) { throw 'OS_AUTH_URL missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_USERNAME)) { throw 'OS_USERNAME missing!' }
  if ([string]::IsNullOrWhitespace($env:OS_TENANT_NAME)) { throw 'OS_TENANT_NAME missing!' }
}
