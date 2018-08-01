#requires -RunAsAdministrator
[CmdletBinding()]
Param(
  [Parameter(HelpMessage = "SSL friendly name")]  
  [ValidateNotNullOrEmpty()]
  [string]$FriendlyName = "DO_NOT_TRUST_Example",
  [Parameter(HelpMessage = "Default website hostname")]
  [ValidateNotNullOrEmpty()]
  [string]$Hostname = "example.local",
  [Parameter(HelpMessage = "SSL DNS hostname")]
  [ValidateNotNullOrEmpty()]
  [string]$SSLHostname = "ssl.example.local"
)

# make our local cert
$filePath = Join-Path ".\cert" -ChildPath "$($FriendlyName).pfx"
If (Test-Path $filePath) {
  Write-Information "Certificate already created, skipping step."
} Else {
  $cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.FriendlyName -eq $FriendlyName }
  If ($null -eq $cert) {
    $cert = New-SelfSignedCertificate -FriendlyName $FriendlyName -DnsName @($Hostname, $SSLHostname) -CertStoreLocation Cert:\LocalMachine\My
    Write-Host "New certificate created, thumbprint $($cert.Thumbprint)"
    
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
    Write-Host "Certificate added to Cert:\LocalMachine\Root"
  } Else {
    Write-Information "Certificate already created, skipping step."
  }
  If (!(Test-Path $filePath)) {
    If (!(Test-Path ".\cert")) {
      New-Item ".\cert" -ItemType Directory | Out-Null
    }
    $PfxPassword = ConvertTo-SecureString "secret" -AsPlainText -Force
    Export-PfxCertificate -Cert $cert -FilePath $filePath -Password $PfxPassword
    Write-Host "Certificate exported to $($filePath)"

    $cert | Remove-Item
  } Else {
    Write-Information "Certificate already exported, skipping step."
  }
  Write-Host "Certificate created and installed."
}

# build image
docker build -t ssl-iis-docker `
  --build-arg CERT=$($filePath) `
  --build-arg HOSTNAME=$($Hostname) `
  --build-arg SSL_HOSTNAME=$($SSLHostname) `
  .