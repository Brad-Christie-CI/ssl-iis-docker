[CmdletBinding()]
Param(
  [Parameter(HelpMessage = "Default website hostname")]
  [ValidateNotNullOrEmpty()]
  [string]$Hostname = "example.local",
  [Parameter(HelpMessage = "SSL DNS hostname")]
  [ValidateNotNullOrEmpty()]
  [string]$SSLHostname = "ssl.example.local"
)

Describe "SSL in IIS with Docker" {
  Context "My Store" {
    $containerId = ""
    $ipAddress = ""

    BeforeEach {
      $containerId = docker run --rm -d ssl-iis-docker:My
      $ipAddress = docker inspect -f "{{ .NetworkSettings.Networks.nat.IPAddress }}" $containerId
    }

    It "Should serve <Protocol>://<HostHeader>" -TestCases @(
      @{ Protocol = "http"; HostHeader = $Hostname }
      #@{ Protocol = "https"; HostHeader = $SSLHostname } # Must be installed to Root store, otherwise invalid cert.
    ) {
      Param($Protocol, $HostHeader)
      $response = Invoke-WebRequest "$($Protocol)://$($ipAddress)/" -Headers @{ Host = $HostHeader; } -UseBasicParsing
      $response | Should -Not -Be $null
      $response.StatusCode | Should -Be 200
    }

    AfterEach {
      docker stop $containerId
    }
  }
  Context "Root Store" {
    $containerId = ""
    $ipAddress = ""

    BeforeEach {
      $containerId = docker run --rm -d ssl-iis-docker:Root
      $ipAddress = docker inspect -f "{{ .NetworkSettings.Networks.nat.IPAddress }}" $containerId
    }

    It "Should serve <Protocol>://<HostHeader>" -TestCases @(
      @{ Protocol = "http"; HostHeader = $Hostname },
      @{ Protocol = "https"; HostHeader = $SSLHostname }
    ) {
      Param($Protocol, $HostHeader)
      $response = Invoke-WebRequest "$($Protocol)://$($ipAddress)/" -Headers @{ Host = $HostHeader; } -UseBasicParsing
      $response | Should -Not -Be $null
      $response.StatusCode | Should -Be 200
    }

    AfterEach {
      docker stop $containerId
    }
  }
}