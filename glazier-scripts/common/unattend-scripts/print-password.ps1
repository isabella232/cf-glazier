
$encryptedPassword = (wget http://169.254.169.254/openstack/2013-04-04/password -UseBasicParsing).Content
Write-Output '-----BEGIN BASE64-ENCODED ENCRYPTED PASSWORD-----'
Write-Output $encryptedPassword
Write-Output '-----END BASE64-ENCODED ENCRYPTED PASSWORD-----'
