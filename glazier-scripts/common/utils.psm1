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
  mkdir $path -ErrorAction 'Stop' | out-null
}

function Convert-ImageNameToFileName{[CmdletBinding()]param($name)
  ($name -replace '[^a-zA-Z0-9\.]+', '-').ToLower()
}

function Download-File-With-Retry{[CmdletBinding()]param($url, $targetFile)
  $retry_left = 5
    while ($true) {
      try {
        Download-File $url $targetFile
        break
      }
      catch {
        if ($retry_left -lt 1) {
          throw
          } 
          else {
            $errorMessage = $_.Exception.Message
            Write-Output "Call failed with exception: ${errorMessage}"
            Write-Verbose $_.Exception
            $retry_left = $retry_left - 1
            Write-Output "Retries left: ${retry_left}"
         }
      }
        
  }
}


function Download-File{[CmdletBinding()]param($url, $targetFile)
  Write-Verbose "Downloading '${url}' to '${targetFile}'"
  try {
    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000) #15 second timeout
    $request.set_KeepAlive($false)
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
    $responseStream = $response.GetResponseStream()
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
    $buffer = new-object byte[] 50KB
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $count
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($count -gt 0) {
      $targetStream.Write($buffer, 0, $count)
      $count = $responseStream.Read($buffer,0,$buffer.length)
      $downloadedBytes = $downloadedBytes + $count

      if ($sw.Elapsed.TotalMilliseconds -ge 500) {
        $activity = "Downloading file '$($url.split('/') | Select -Last 1)'"
        $status = "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): "
        $percentComplete = ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
        Write-Progress -activity $activity -status $status -PercentComplete $percentComplete

        $sw.Reset()
        $sw.Start()
      }
    }

    Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Done"
  }
  finally {
    if ($targetStream -ne $null) {
      $targetStream.Flush()
      $targetStream.Close()
      $targetStream.Dispose()
    }
    if ($responseStream -ne $null) {
      $responseStream.Dispose()
    }
  }
}

function Import-509Certificate{[CmdletBinding()]param($certPath, $certRootStore, $certStore)
  Write-Verbose "Importing certificate '${certPath}' to '${certRootStore}\${certStore}'"
  try
  {
    $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
    $pfx.import([string]$certPath)

    $store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore,$certRootStore)
    $store.open("MaxAllowed")
    $store.add($pfx)
    $store.close()
  }
  catch
  {
    $errorMessage = $_.Exception.Message
    Write-Output "Could not import certificate '${certPath}': ${errorMessage}"
  }
}

function Configure-SSLErrors{[CmdletBinding()]param()
  If ( $env:OS_INSECURE -match "true" )
  {
    add-type @"
      using System.Net;
      using System.Security.Cryptography.X509Certificates;
      public class TrustAllCertsPolicy : ICertificatePolicy {
          public bool CheckValidationResult(
              ServicePoint srvPoint, X509Certificate certificate,
              WebRequest request, int certificateProblem) {
              return true;
          }
      }
"@

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
  }
}

function Set-SystemProxy{[CmdletBinding()]param()
  Write-Verbose "Setting system proxy ..."
  $httpProxy = Get-HttpProxy
  $httpsProxy = Get-HttpsProxy
  $httpProxyObj = $null
  $httpsProxyObj = $null

  $Source = @" 
using System;
using System.Net;

namespace Proxy
{
   public class SimpleProxy : IWebProxy
    {
        private Uri httpProxyUrl = null;
        private Uri httpsProxyUrl = null;

        public SimpleProxy(Uri httpProxyUrl, Uri httpsProxyUrl)
        {
            this.httpProxyUrl = httpProxyUrl;
            this.httpsProxyUrl = httpsProxyUrl;
        }

        public Uri GetProxy(Uri destination)
        {
            if (destination.Scheme == "https" && this.httpsProxyUrl != null)
            {
                return this.httpsProxyUrl;
            }
            else
            {
                return this.httpProxyUrl;
            }
        }

        public bool IsBypassed(Uri host)
        {
            if (httpProxyUrl == null && httpsProxyUrl == null)
            {
                return true;
            }
            return false;
        }

        public ICredentials Credentials
        {
            get;
            set;
        }
    }
}

"@ 
  
  Add-Type -TypeDefinition $Source -Language CSharp
  

  if (![string]::IsNullOrWhitespace($httpProxy)) {
     try 
     {
        Write-Verbose "Trying to set HTTP proxy to $httpProxy" 
        $httpProxyObj = New-Object System.Uri -ArgumentList $httpProxy
        $env:HTTP_PROXY=$httpProxy
    }
    Catch 
    {
       Write-Verbose $_.Exception
    }

  }
  
  if (![string]::IsNullOrWhitespace($httpsProxy)) {
     try 
     {
     Write-Verbose "Trying to set HTTPS proxy to $httpsProxy" 
       $httpsProxyObj = New-Object System.Uri -ArgumentList $httpsProxy
       $env:HTTPS_PROXY=$httpsProxy
    }
    Catch 
    {
      Write-Verbose $_.Exception
    }
  }

  $proxy = New-Object Proxy.SimpleProxy -ArgumentList $httpProxyObj, $httpsProxyObj
  [System.Net.WebRequest]::DefaultWebProxy = $proxy

  
  if ((![string]::IsNullOrWhitespace($httpProxy)) -or (![string]::IsNullOrWhitespace($httpsProxy))) {
    $env:NO_PROXY='localhost,127.0.0.1,localaddress,0.0.0.0/8,10.0.0.0/8,127.0.0.0/8,169.254.0.0/16,172.16.0.0/12,192.0.2.0/8,192.88.99.0/8,192.168.0.0/16,198.18.0.0/15,224.0.0.0/4,240.0.0.0/4'
  }
}
