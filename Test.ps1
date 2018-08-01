#requires -RunAsAdministrator

[CmdletBinding()]
Param(
  [Parameter(HelpMessage = "Default website hostname")]
  [ValidateNotNullOrEmpty()]
  [string]$Hostname = "example.local",
  [Parameter(HelpMessage = "SSL DNS hostname")]
  [ValidateNotNullOrEmpty()]
  [string]$SSLHostname = "ssl.example.local"
)

Write-Host "Starting container"
$containerId = docker run -d --name ssl-iis-docker ssl-iis-docker:latest

Write-Host "Retrieving IP address"
$ipAddress = docker inspect -f "{{ .NetworkSettings.Networks.nat.IPAddress }}" ssl-iis-docker
Write-Host "IP: $($ipAddress)"

Write-Host "Performing HTTP test (https://$($Hostname)/))"
$http = Invoke-WebRequest "http://$($ipAddress)/" -Headers @{ Host = $Hostname; } -UseBasicParsing
If ($http.StatusCode -eq 200) {
  Write-Host "HTTP page successfully retrieved."

  Write-Host "Perorming HTTPS test (https://$($SSLHostname)/)"
  $https = Invoke-WebRequest "https://$($ipAddress)/" -Headers @{ Host = $SSLHostname; } -UseBasicParsing
  If ($https.StatusCode -eq 200) {
    Write-Host "HTTPS page sucessfully retrieved."
  } Else {
    Write-Warning "HTTPS request failed."
  }
} Else {
  Write-Warning "HTTP request failed."
}

Write-Host "Stopping container"
docker rm -f $containerId

Write-Host "Test complete"