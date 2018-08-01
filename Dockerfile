#escape=`
FROM microsoft/windowsservercore
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG CERT
ARG HOSTNAME=example.local
ARG SSL_HOSTNAME=ssl.example.local

COPY $CERT \cert.pfx
WORKDIR \

RUN $PfxPassword = ConvertTo-SecureString "secret" -AsPlainText -Force ; `
    $cert = Import-PfxCertificate -FilePath \cert.pfx -CertStoreLocation Cert:\LocalMachine\My -Password $PfxPassword -Exportable ; `
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store Root, LocalMachine ; `
    $store.Open('MaxAllowed') ; $store.Add($cert) ; $store.Close() ; `
    Add-WindowsFeature Web-Server ; `
    $siteName = Get-Website | Select-Object -ExpandProperty Name -First 1 ; `
    New-WebBinding -Name $siteName -Protocol http -HostHeader $env:HOSTNAME ; `
    New-WebBinding -Name $siteName -Protocol https -HostHeader $env:SSL_HOSTNAME -SslFlags 1 ; `
    $binding = Get-WebBinding -Name $siteName -Protocol https -HostHeader $env:SSL_HOSTNAME ; `
    $binding.AddSslCertificate($cert.Thumbprint, 'Root')

RUN Invoke-WebRequest "https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.3/ServiceMonitor.exe" -OutFile "ServiceMonitor.exe" -UseBasicParsing

EXPOSE 80 443

ENTRYPOINT ["ServiceMonitor.exe", "w3svc"]