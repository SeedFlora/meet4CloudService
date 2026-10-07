# Pemeriksaan baca-saja Lab 04. Tidak membuat, menghentikan, atau menghapus container.
param(
    [string]$SiteName = 'cloudlab-site',
    [string]$CanaryName = 'cloudlab-canary',
    [ValidateRange(1, 65535)][int]$SitePort = 8088,
    [ValidateRange(1, 65535)][int]$CanaryPort = 8089
)

$script:PassCount = 0
$script:FailCount = 0

function Pass([string]$Label) {
    Write-Output "PASS $Label"
    $script:PassCount++
}

function Fail([string]$Label, [string]$Hint) {
    Write-Output "FAIL $Label"
    Write-Output "     -> $Hint"
    $script:FailCount++
}

function DockerText([string[]]$Arguments) {
    $result = & docker @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return (@($result) -join "`n").Trim()
}

function PageAt([int]$Port) {
    try {
        return Invoke-WebRequest -Uri "http://127.0.0.1:$Port/" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    }
    catch {
        return $null
    }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail 'Docker Engine tersedia' 'Instal/jalankan Docker Desktop atau Engine, lalu cek docker version.'
    Write-Output "Challenge: $($script:PassCount) PASS, $($script:FailCount) FAIL"
    exit 1
}
$null = DockerText @('info', '--format', '{{.ServerVersion}}')
if ($LASTEXITCODE -ne 0) {
    Fail 'Docker Engine tersedia' 'Jalankan Docker Desktop atau Engine, lalu cek docker version.'
    Write-Output "Challenge: $($script:PassCount) PASS, $($script:FailCount) FAIL"
    exit 1
}

foreach ($image in @('nginx:alpine', 'python:3.12-alpine', 'node:22-alpine')) {
    $id = DockerText @('image', 'inspect', $image, '--format', '{{.Id}}')
    if ($id) {
        Pass "A image $image tersedia"
    }
    else {
        Fail "A image $image tersedia" "Jalankan docker pull $image."
    }
}

$siteState = DockerText @('inspect', '--format', '{{.State.Running}}|{{.Config.Image}}', $SiteName)
if ($siteState -eq 'true|nginx:alpine') {
    Pass "B $SiteName berjalan dari nginx:alpine"
}
else {
    Fail "B $SiteName berjalan dari nginx:alpine" "Jalankan Nginx dengan --name $SiteName; cek docker ps -a dan docker logs $SiteName."
}

$siteBinding = DockerText @('port', $SiteName, '80/tcp')
if ($siteBinding -eq "127.0.0.1:$SitePort") {
    Pass "B port $SitePort hanya di 127.0.0.1"
}
else {
    Fail "B port $SitePort hanya di 127.0.0.1" "Gunakan -p 127.0.0.1:${SitePort}:80; cek docker port $SiteName."
}

$siteDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\site'))
$expectedSource = $siteDir.Replace('\', '/').TrimEnd('/')
$mountJson = DockerText @('inspect', '--format', '{{json .Mounts}}', $SiteName)
$mountMatches = $false
if ($mountJson) {
    try {
        $mounts = @(ConvertFrom-Json -InputObject $mountJson)
        foreach ($mount in $mounts) {
            $actualSource = ([string]$mount.Source).Replace('\', '/').TrimEnd('/')
            if ($mount.Destination -eq '/usr/share/nginx/html' -and
                $mount.Type -eq 'bind' -and
                $mount.RW -eq $false -and
                [string]::Equals($actualSource, $expectedSource, [System.StringComparison]::OrdinalIgnoreCase)) {
                $mountMatches = $true
            }
        }
    }
    catch {
        $mountMatches = $false
    }
}
if ($mountMatches) {
    Pass 'B folder site/ di-bind mount read-only'
}
else {
    Fail 'B folder site/ di-bind mount read-only' "Jalankan dari root repo dengan --mount type=bind,source=<path site>,target=/usr/share/nginx/html,readonly; cek docker inspect $SiteName."
}

$sitePage = PageAt $SitePort
if ($null -ne $sitePage -and $sitePage.StatusCode -eq 200) {
    Pass "C halaman utama HTTP 200 di $SitePort"
}
else {
    Fail "C halaman utama HTTP 200 di $SitePort" "Buka http://127.0.0.1:$SitePort/; cek docker logs $SiteName."
}
$siteBody = if ($null -ne $sitePage) { [string]$sitePage.Content } else { '' }
if ($siteBody.Contains('INCIDENT-042: Pemeliharaan selesai')) {
    Pass 'D halaman menampilkan INCIDENT-042: Pemeliharaan selesai'
}
else {
    Fail 'D halaman menampilkan INCIDENT-042: Pemeliharaan selesai' 'Ganti literal STATUS_OK: Layanan normal di site/index.html, simpan, lalu muat ulang.'
}
if ($siteBody -and -not $siteBody.Contains('STATUS_OK: Layanan normal')) {
    Pass 'D status lama sudah diganti'
}
else {
    Fail 'D status lama sudah diganti' 'Pastikan halaman tidak lagi menampilkan STATUS_OK: Layanan normal.'
}

$canaryState = DockerText @('inspect', '--format', '{{.State.Running}}|{{.Config.Image}}', $CanaryName)
if ($canaryState -eq 'true|nginx:alpine') {
    Pass "E $CanaryName berjalan dari nginx:alpine"
}
else {
    Fail "E $CanaryName berjalan dari nginx:alpine" "Jalankan container kedua dengan --name $CanaryName, tanpa menghentikan $SiteName."
}

$canaryBinding = DockerText @('port', $CanaryName, '80/tcp')
if ($canaryBinding -eq "127.0.0.1:$CanaryPort") {
    Pass "E port $CanaryPort hanya di 127.0.0.1"
}
else {
    Fail "E port $CanaryPort hanya di 127.0.0.1" "Gunakan -p 127.0.0.1:${CanaryPort}:80."
}

$canaryPage = PageAt $CanaryPort
if ($null -ne $canaryPage -and $canaryPage.StatusCode -eq 200) {
    Pass "E canary HTTP 200 di $CanaryPort"
}
else {
    Fail "E canary HTTP 200 di $CanaryPort" "Cek docker logs $CanaryName dan http://127.0.0.1:$CanaryPort/."
}

$sitePorts = DockerText @('port', $SiteName)
if ($sitePorts -eq "80/tcp -> 127.0.0.1:$SitePort") {
    Pass "E $SiteName tidak membuka port host lain"
}
else {
    Fail "E $SiteName tidak membuka port host lain" "Cek docker port $SiteName; terbitkan hanya 127.0.0.1:${SitePort}:80."
}
$canaryPorts = DockerText @('port', $CanaryName)
if ($canaryPorts -eq "80/tcp -> 127.0.0.1:$CanaryPort") {
    Pass "E $CanaryName tidak membuka port host lain"
}
else {
    Fail "E $CanaryName tidak membuka port host lain" "Cek docker port $CanaryName; terbitkan hanya 127.0.0.1:${CanaryPort}:80."
}

Write-Output ''
Write-Output "Challenge: $($script:PassCount) PASS, $($script:FailCount) FAIL"
if ($script:FailCount -gt 0) { exit 1 }
