$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir './utils.psm1')
Import-Module -DisableNameChecking (Join-Path $currentDir './openstack-tools.psm1')


function Get-SwiftUrl{[CmdletBinding()]param()
  try
  {
    # Do not use swift storage on HP Public Cloud
    if ($env:OS_AUTH_URL -like '*.hpcloudsvc.com:*')
    {
    #  throw "Cannot use Swift with glazier on HP public cloud."
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
        return $null
    }

    $endpoint = ($objectStore.endpoints | ? {$_.region -eq $env:OS_REGION_NAME})

    if ($endpoint -eq $null)
    {
      return $null
    }

    return $endpoint.publicUrl
  }
  catch
  {
    $errorMessage = $_.Exception.Message
    Write-Verbose "Error while trying to find a swift store: ${errorMessage}"
    return $null
  }
}

function Get-Token{[CmdletBinding()]param()
  try
  {
    # Do not use swift storage on HP Public Cloud
    if ($env:OS_AUTH_URL -like '*.hpcloudsvc.com:*')
    {
    #  throw "Cannot use Swift with glazier on HP public cloud."
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

    return $jsonResponse.access.token.id
  }
  catch
  {
    $errorMessage = $_.Exception.Message
    Write-Verbose "Error while trying to get a token: ${errorMessage}"
    return $null
  }
}

function Upload-SwiftNative{[CmdletBinding()]param($localFile, $container, $object, $chunkSizeBytes, $retryCount, $withChaos)
  # Validation
  if (!(Test-Path $localFile))
  {
    throw "File '${localFile}' does not exist."
  }

  # Create a prefix
  $prefix = "$([guid]::NewGuid().ToString('N'))_"
  Write-Verbose "Prefix will be '${prefix}'"

  # Create Container
  Create-SwiftContainer $container

  # Create Segment Container
  $segmentContainer = "${container}_segments"
  Create-SwiftContainer $segmentContainer

  # Authenticate
  $token = Get-Token
  Write-Verbose "Using token '${token}'"

  # Get Swift URL
  $swiftUrl = Get-SwiftUrl
  Write-Verbose "Using swift at '${swiftUrl}'"

  # Calculate chunks
  $fileInfo = [System.IO.FileInfo]$localFile
  $fileSizeBytes = $fileInfo.Length
  $fileSizeMB = $fileInfo.Length / (1024.0 * 1024.0)
  Write-Output "File size is $($fileInfo.Length) bytes (${fileSizeMB} MB)."

  $chunkSizeMB = $chunkSizeBytes / (1024.0 * 1024.0)
  $completeChunkCount = [math]::Floor([double]$fileSizeBytes / [double]$chunkSizeBytes)
  Write-Output "Chunk size is ${chunkSizeBytes} bytes (${chunkSizeMB} MB)."

  $lastChunkSizeBytes = $fileSizeBytes % $chunkSizeBytes
  $chunkCount = $completeChunkCount
  if ($lastChunkSizeBytes -ne 0)
  {
    $chunkCount += 1
    $lastChunkSizeMB = $lastChunkSizeBytes / (1024.0 * 1024.0)
    Write-Output "Final chunk will be ${lastChunkSizeBytes} bytes (${lastChunkSizeMB} MB)."
  }

  Write-Output "Will be uploading ${chunkCount} chunks."

  # Iterate through chunks
  for ($idx = 0; $idx -lt $completeChunkCount; $idx++)
  {
    # Calculate offset
    $offset = $idx * $chunkSizeBytes

    # Resolve out upload url
    $uploadUrl = Get-ChunkUrl $swiftUrl $segmentContainer $prefix $idx

    $activity = "Uploading object to swift ..."
    $status = "Uploading segment #$($idx + 1) of ${chunkCount}"
    $percentComplete = ($idx / $chunkCount)  * 100
    Write-Progress -Id 1 -activity $activity -status $status -PercentComplete $percentComplete

    # Upload chunk
    Upload-ChunkWithRetries $localFile $uploadUrl $token $offset $chunkSizeBytes $retryCount $withChaos
  }

  # Upload last chunk, if any
  if ($lastChunkSizeBytes -ne 0)
  {
    $idx = $chunkCount - 1

    # Calculate offset
    $offset = $completeChunkCount * $chunkSizeBytes

    # Resolve out upload url
    $uploadUrl = Get-ChunkUrl $swiftUrl $segmentContainer $prefix $idx

    $activity = "Uploading object to swift ..."
    $status = "Uploading segment #$($idx + 1) of ${chunkCount}"
    $percentComplete = ($idx / $chunkCount)  * 100
    Write-Progress -Id 1 -activity $activity -status $status -PercentComplete $percentComplete

    # Upload chunk
    Upload-ChunkWithRetries $localFile $uploadUrl $token $offset $lastChunkSizeBytes $retryCount $withChaos
  }

  Write-Progress -Id 1 -activity "Uploading object to swift ..." -status "Done" -PercentComplete 100

  # Create manifest
  $manifestUrl = Get-ManifestUrl $swiftUrl $container $object
  Create-ManifestWithRetries $manifestUrl $token $container $segmentContainer $object $prefix $retryCount $withChaos
}

function Create-ManifestWithRetries{[CmdletBinding()]param($remoteUrl, $token, $container, $segmentContainer, $object, $prefix, $retryCount, $withChaos)
  $createdOK = $false
  $remainingRetryCount = [math]::Max($retryCount, 1)

  while (($createdOK -eq $false) -and ($remainingRetryCount -gt 0))
  {
    try
    {
      Create-Manifest $remoteUrl $token $container $segmentContainer $object $prefix $withChaos
      $createdOK = $true
    }
    catch
    {
      $errorMessage = $_.Exception.Message
      $createdOK = $false
      $remainingRetryCount -= 1
      Write-Warning "Manifest was not created ok, trying again (retries remaining: ${remainingRetryCount}) ..."
      Write-Verbose "${errorMessage}"
    }
  }

  if ($chunkUploadedOK -eq $false)
  {
    throw "Could not create the manifest on swift for '${localFile}' after ${retryCount} retries. Aborting."
  }
}

function Create-Manifest{[CmdletBinding()]param($remoteUrl, $token, $container, $segmentContainer, $object, $prefix, $withChaos)
  Write-Verbose "Creating manifest object ..."

  try
  {
    $request = [System.Net.HttpWebRequest]::Create($remoteUrl)
    $request.Headers.Add("X-Auth-Token", $token)
    $request.Headers.Add("X-Object-Manifest", "${segmentContainer}/${prefix}")

    $buffer = New-Object byte[] 0

    $request.Method = "PUT"
    $requestStream = $request.GetRequestStream()
    $requestStream.Write($buffer, 0, 0)

    if ($withChaos)
    {
      if (((Get-Random) % 3) -eq 0)
      {
        throw "CHAOS MONKEY!"
      }
    }
  }
  finally
  {
    if ($requestStream -ne $null)
    {
      $requestStream.Close()

      try
      {
        [System.Net.HttpWebResponse]$response = $request.GetResponse();

        if ([int]$response.StatusCode -ne 201)
        {
          $responseStream = $response.GetResponseStream();
          [System.IO.StreamReader] $streamReader = New-Object System.IO.StreamReader -argumentList $responseStream;
          [string] $results = $streamReader.ReadToEnd();
          throw "Server replied with status code $([int]$response.StatusCode) (expected 201): ${results}";
        }
      }
      finally
      {
        if ($responseStream -ne $null)
        {
          $responseStream.Close()
        }

        if ($streamReader -ne $null)
        {
          $streamReader.Close()
        }
      }
    }
  }
}

function Upload-ChunkWithRetries{[CmdletBinding()]param($localFile, $remoteUrl, $token, $offset, $chunkSize, $retryCount, $withChaos)
  $chunkUploadedOK = $false
  $remainingRetryCount = [math]::Max($retryCount, 1)

  while (($chunkUploadedOK -eq $false) -and ($remainingRetryCount -gt 0))
  {
    try
    {
      # Upload chunk
      Upload-Chunk $localFile $uploadUrl $token $offset $chunkSize $withChaos
      $chunkUploadedOK = $true
    }
    catch
    {
      $errorMessage = $_.Exception.Message
      $chunkUploadedOK = $false
      $remainingRetryCount -= 1
      Write-Warning "Chunk #${idx} did not upload ok, trying again (retries remaining: ${remainingRetryCount}) ..."
      Write-Verbose "${errorMessage}"
    }
  }

  if ($chunkUploadedOK -eq $false)
  {
    throw "Could not upload a chunk of '${localFile}' to swift after ${retryCount} retries. Aborting."
  }
}

function Upload-Chunk{[CmdletBinding()]param($localFile, $remoteUrl, $token, $offset, $chunkSize, $withChaos)
  Write-Verbose "segment:${remoteUrl}"
  Write-Verbose "   offset:${offset} size:${chunkSize}"

  $bufferSize = [math]::Min($chunkSize, 50 * 1024)
  $buffer = New-Object byte[] $bufferSize
  $bytesRemaining = $chunkSize

  try
  {
    $reader = New-Object System.IO.FileStream $localFile, "Open"
    $reader.Seek($offset, "Begin") | Out-Null

    $request = [System.Net.HttpWebRequest]::Create($remoteUrl)
    $request.ReadWriteTimeout = 1000 * 60 * 30
    $request.Timeout = 1000 * 60 * 30
    $request.KeepAlive = $false

    $request.AllowWriteStreamBuffering = $false
    $request.ContentLength = $chunkSize
    $request.Headers.Add("X-Auth-Token", $token)
    $request.Method = "PUT"
    $requestStream = $request.GetRequestStream()

    $swChild = [System.Diagnostics.Stopwatch]::StartNew()

    while ($bytesRemaining -gt 0)
    {
      $countToRead = [math]::Min($bytesRemaining, $buffer.Length)
      $readCount = $reader.Read($buffer, 0, $countToRead)
      $bytesRemaining -= $readCount
      $requestStream.Write($buffer, 0, $readCount)

      if ($swChild.Elapsed.TotalMilliseconds -ge 100)
      {
        $activity = "Uploading segment with offset ${offset} ..."
        $doneBytes = $chunkSize - $bytesRemaining
        $status = "Uploaded (${doneBytes} bytes of (${chunkSize}) bytes: "
        $percentComplete = ($doneBytes / $chunkSize)  * 100
        Write-Progress -Id 2 -ParentId 1 -activity $activity -status $status -PercentComplete $percentComplete

        $swChild.Reset()
        $swChild.Start()
      }

      if ($withChaos)
      {
        if (((Get-Random) % 3) -eq 0)
        {
          throw "CHAOS MONKEY!"
        }
      }
    }

    Write-Progress -Id 2 -ParentId 1 -activity "Uploading segment with offset ${offset} ..." -status "Done" -PercentComplete 100
  }
  finally
  {
    if ($reader -ne $null)
    {
      $reader.Close()
    }

    if ($requestStream -ne $null)
    {
      $requestStream.Close()

      try
      {
        [System.Net.HttpWebResponse]$response = $request.GetResponse();

        if ([int]$response.StatusCode -ne 201)
        {
          $responseStream = $response.GetResponseStream();
          [System.IO.StreamReader] $streamReader = New-Object System.IO.StreamReader -argumentList $responseStream;
          [string] $results = $streamReader.ReadToEnd();
          throw "Server replied with status code $([int]$response.StatusCode) (expected 201): ${results}";
        }
      }
      finally
      {
        if ($responseStream -ne $null)
        {
          $responseStream.Close()
        }

        if ($streamReader -ne $null)
        {
          $streamReader.Close()
        }
      }
    }
  }
}

function Get-ManifestUrl{[CmdletBinding()]param($swiftUrl, $container, $object)
  [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
  $url = [UriBuilder]"${swiftUrl}"
  $url.Path = Join-Path $url.Path "${container}/${object}"
  return $url.Uri.AbsoluteUri.ToString()
}

function Get-ChunkUrl{[CmdletBinding()]param($swiftUrl, $container, $prefix, $index)
  [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
  $url = [UriBuilder]"${swiftUrl}"
  $url.Path = Join-Path $url.Path "${container}/${prefix}$($index.ToString('0000000'))"
  return $url.Uri.AbsoluteUri.ToString()
}
