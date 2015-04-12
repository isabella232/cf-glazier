$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

function Check-IsAdmin{[CmdletBinding()]param()
  Write-Verbose "Checking to see if we're running in an adminstrative shell ..."
  $wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $prp = new-object System.Security.Principal.WindowsPrincipal($wid)
  $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
  $isAdmin = $prp.IsInRole($adm)
  if(!$isAdmin)
  {
      throw "This cmdlet must be executed in an elevated administrative shell"
  }
}

function Get-Dependency{[CmdletBinding()]param($name)
  $dependenciesFile = 'dependencies.csv'
  $dependencies = Import-Csv (Join-Path $currentDir $dependenciesFile)
  $dependency = $dependencies | where { $_.Name -eq $name }

  if ($dependency -eq $null)
  {
    throw "Could not resolve dependency ${name}."
  }
  else
  {
    $dependencyUri = $dependency.uri
    Write-Verbose "Dependency '${name}' resolved to '${dependencyUri}'."
    return $dependencyUri
  }
}

function Clean-Dir{[CmdletBinding()]param($path)
  Write-Verbose "Cleaning directory ${$path}"
  rm -Recurse -Force -Confirm:$false $path -ErrorAction SilentlyContinue
  mkdir $path | out-null
}

function Convert-ImageNameToFileName{[CmdletBinding()]param($name)
  ($name -replace '[^a-zA-Z0-9\.]+', '-').ToLower()
}

function Download-File{[CmdletBinding()]param($url, $targetFile)
  Write-Verbose "Downloading '${url}' to '${targetFile}'"
  $uri = New-Object "System.Uri" "$url"
  $request = [System.Net.HttpWebRequest]::Create($uri)
  $request.set_Timeout(15000) #15 second timeout
  $response = $request.GetResponse()
  $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
  $responseStream = $response.GetResponseStream()
  $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
  $buffer = new-object byte[] 100KB
  $count = $responseStream.Read($buffer,0,$buffer.length)
  $downloadedBytes = $count

  while ($count -gt 0)
  {
     $targetStream.Write($buffer, 0, $count)
     $count = $responseStream.Read($buffer,0,$buffer.length)
     $downloadedBytes = $downloadedBytes + $count
     Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
  }

  Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'" -status "Done"
  $targetStream.Flush()
  $targetStream.Close()
  $targetStream.Dispose()
  $responseStream.Dispose()
}
