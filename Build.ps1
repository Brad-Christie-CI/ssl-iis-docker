#requires -RunAsAdministrator
[CmdletBinding()]
Param(
  [Parameter(HelpMessage = "SSL friendly name")]  
  [ValidateNotNullOrEmpty()]
  [string]$FriendlyNamePrefix = "DO_NOT_TRUST_Example",
  [Parameter(HelpMessage = "Default website hostname")]
  [ValidateNotNullOrEmpty()]
  [string]$Hostname = "example.local",
  [Parameter(HelpMessage = "SSL DNS hostname")]
  [ValidateNotNullOrEmpty()]
  [string]$SSLHostname = "ssl.example.local",

  [Parameter(HelpMessage = "Clean environment before build")]
  [switch]$Clean
)
$ErrorActionPreference = "Stop"
If ($Clean) {
  Remove-Item ".\cert" -Recurse -Force -ErrorAction SilentlyContinue

  Get-ChildItem Cert:\LocalMachine\Root, Cert:\LocalMachine\My | Where-Object {
    ($_.DnsNameList | Where-Object {
      ($_.Punycode -contains $Hostname) -or ($_.Punycode -contains $SSLHostname)
    }).Count -ne 0
  } | Remove-item -Force
}

@("My", "Root") | ForEach-Object {
  $storeName = $_
  $friendlyName = "$($FriendlyNamePrefix)_$($storeName)"

  Write-Host "Making Cert:\LocalMachine\$($storeName) certificate"
  $filePath = Join-Path ".\cert" -ChildPath "$($storeName).pfx"
  $cert = Get-ChildItem "Cert:\LocalMachine\$($storeName)" | Where-Object { $_.FriendlyName -eq $friendlyName }
  If ($null -eq $cert) {
    $cert = New-SelfSignedCertificate -FriendlyName $friendlyName -DnsName @($Hostname, $SSLHostname) -CertStoreLocation "Cert:\LocalMachine\My"
    Write-Host "New certificate created, thumbprint $($cert.Thumbprint)"
      
    If ($storeName -eq "Root") {
      $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
      $store.Open("ReadWrite")
      $store.Add($cert)
      $store.Close()
      Write-Host "Certificate added to Cert:\LocalMachine\Root"
    }
  } Else {
    Write-Host "Pre-existing certificate found, skipping."
  }

  If (!(Test-Path $filePath)) {
    $parent = Split-Path $filePath -Parent
    If (!(Test-Path $parent)) {
      New-Item $parent -ItemType Directory | Out-Null
    }
    $Password = ConvertTo-SecureString "secret" -AsPlainText -Force
    Export-PfxCertificate -Cert $Cert -FilePath $filePath -Password $Password | Out-Null
    Write-Host "Certificate exported to $($filePath)"
  } Else {
    Write-Host "Certificate found at $($filePath)"
  }

  If ($storeName -eq "Root") {
    $cert | Remove-Item
  }

  # build image
  docker build -t ssl-iis-docker:$($storeName) `
    --build-arg CERT=$($filePath) `
    --build-arg HOSTNAME=$($Hostname) `
    --build-arg SSL_HOSTNAME=$($SSLHostname) `
    --build-arg INSTALL_ROOT=$($installRootArg) `
    .
}