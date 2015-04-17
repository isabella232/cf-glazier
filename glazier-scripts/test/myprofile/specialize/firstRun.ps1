function SetupWinRM($port, $hostName)
{
  Write-Output 'Setting up WinRM ...'

  Write-Output "Generating a new self-signed cert ..."
  $cert = New-SelfSignedCertificate -DnsName $hostName -CertStoreLocation cert:\localmachine\my
  $thumbprint = $cert.Thumbprint

  Write-Output "Cleanup WinRM settings ..."
  cmd /c 'winrm delete winrm/config/Listener?Address=*+Transport=HTTP'
  cmd /c 'winrm delete winrm/config/Listener?Address=*+Transport=HTTPS'

  Write-Output "Creating WinRM configuration ..."
  & cmd /c "winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=`"${hostName}`";CertificateThumbprint=`"${thumbprint}`";Port=`"${port}`"}"

  Write-Output "Enabling certificate authentication ..."
  & cmd /c  'winrm set winrm/config/client/auth @{Certificate="true"}'

  Write-Output "Opening firewall port ${port}"
  & netsh advfirewall firewall add rule name="WinRM" protocol=TCP dir=in localport=${port} action=allow
}

function SetupStackatoUser()
{
  Write-Output 'Setting up stackato user ...'

  $computername = $Env:COMPUTERNAME
  $username = "stackato"

  $Computer = [ADSI]"WinNT://$computername,Computer"
  $LocalAdmin = $Computer.Create("User", $username)
  $LocalAdmin.SetPassword("St@ckato")
  $LocalAdmin.SetInfo()
  $LocalAdmin.FullName = "stackato"
  $LocalAdmin.SetInfo()
  $LocalAdmin.Description = "Stackato account used for setup"
  $LocalAdmin.SetInfo()
  $LocalAdmin.UserFlags = 65536
  $LocalAdmin.SetInfo()

  $group = [ADSI]("WinNT://$computername/administrators,group")
  $group.add("WinNT://$username,user")
}

SetupWinRM 5986 '127.0.0.1'
SetupStackatoUser
