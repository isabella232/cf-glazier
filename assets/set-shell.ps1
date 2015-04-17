$RegPath = "Microsoft.Powershell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\winlogon"
Set-ItemProperty -Path $RegPath -Name Shell -Value 'Powershell.exe -noExit -File "A:\shell.ps1"'
