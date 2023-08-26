$TimeStampServer = "http://timestamp.digicert.com"

$PS1 = "./script.ps1"

# Query the code-signing certificate from the your certificate store
$codeCert = Get-ChildItem Cert:\CurrentUser\My | Where-Object {$_.Subject -eq "CN=3le4ms1"}

# Sign the PowerShell script
Set-AuthenticodeSignature -FilePath $PS1 -Certificate $codeCert -TimeStampServer $TimeStampServer
