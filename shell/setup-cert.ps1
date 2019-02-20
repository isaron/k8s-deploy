function Check-Certificate {
    param
    (
        [string] $CertName
    )
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "CurrentUser", "LocalMachine"
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $storecollection = [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]$store.Certificates
    $find = 0
    foreach ($x509 in $storecollection) {
        $sub = $x509.Subject
        if ($sub.contains($CertName)) {
            $find = 1
            break
        }
    }
    if ($find -eq 1) {
        "'$CertName' certificate has been Successfully installed!"
    }
    else {
        "could not fond '$CertName' please run setup.ps1 frist!"
    }
    $store.Close()
}
Check-Certificate -CertName "要查找证书的subject"
Write-Host 'Press Any Key to exist!' -NoNewline
$null = [Console]::ReadKey('?')