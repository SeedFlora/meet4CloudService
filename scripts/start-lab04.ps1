# Mulai/perbaiki situs Lab 04 dari lokasi script, bukan lokasi terminal.
[CmdletBinding()]
param(
    [ValidateRange(1, 65535)][int]$SitePort = 8088,
    [ValidatePattern('^cloudlab-[a-z0-9][a-z0-9_.-]*$')]
    [string]$ContainerName = 'cloudlab-site',
    [switch]$Repair,
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-LabDocker([string[]]$Arguments) {
    # Tangkap stderr native tanpa menghentikan pemeriksaan exit code di PS 5.1.
    $ErrorActionPreference = 'Continue'
    $lines = @(& docker @Arguments 2>&1)
    $code = $LASTEXITCODE
    [pscustomobject]@{
        Code = $code
        Output = (@($lines | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    }
}

function Require-LabDocker([string[]]$Arguments) {
    $result = Invoke-LabDocker $Arguments
    if ($result.Code -ne 0) { throw "Docker gagal: $($result.Output)" }
    return $result.Output
}

try {
    if ($ContainerName -in @('cloudlab-canary', 'cloudlab-nginx')) {
        throw 'Nama canary/nginx pertama tidak boleh menjadi target starter situs. Gunakan cloudlab-site.'
    }
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
    $indexFile = Join-Path $repoRoot 'site\index.html'
    if (-not (Test-Path -LiteralPath $indexFile -PathType Leaf)) {
        throw "STOP: $indexFile tidak ditemukan. Pakai script dari repo Lab 04 lengkap; jangan membuat folder site kosong."
    }
    if ((Get-Item -LiteralPath $indexFile).Length -eq 0) {
        throw 'STOP: site/index.html kosong. Pulihkan file dari repo sebelum membuat container.'
    }
    $siteDir = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'site')).ProviderPath
    $mountArgument = "type=bind,source=$siteDir,target=/usr/share/nginx/html,readonly"
    Write-Output "REPO: $repoRoot"
    Write-Output "HTML: $indexFile"
    Write-Output "MOUNT: $mountArgument"
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker CLI belum tersedia. Jalankan Git/Docker Desktop yang disiapkan kampus.'
    }
    $engine = Require-LabDocker @('info', '--format', '{{.OSType}}')
    if ($engine -notmatch '(?m)^linux\s*$') {
        throw 'Gunakan Docker Linux Engine sebelum menjalankan image Nginx lab.'
    }
    if ($CheckOnly) {
        Write-Output 'CHECK_OK: file dan Linux Engine siap; tidak ada container yang diubah.'
        return
    }

    $namesText = Require-LabDocker @('ps', '-a', '--format', '{{.Names}}')
    $existingNames = @($namesText -split '\r?\n' | Where-Object { $_ })
    $conflicts = @()
    if ($existingNames -contains $ContainerName) { $conflicts += $ContainerName }
    if ($ContainerName -eq 'cloudlab-site' -and $existingNames -contains 'cloudlab-nginx') {
        $legacyJson = Require-LabDocker @('inspect', 'cloudlab-nginx')
        $legacy = @(ConvertFrom-Json -InputObject $legacyJson)[0]
        $ports = @()
        if ($null -ne $legacy.HostConfig.PortBindings) {
            $binding = $legacy.HostConfig.PortBindings.PSObject.Properties['80/tcp']
            if ($null -ne $binding) { $ports = @($binding.Value | ForEach-Object { [string]$_.HostPort }) }
        }
        if ($ports -contains [string]$SitePort) {
            $conflicts += 'cloudlab-nginx'
        }
    }
    # Validasi seluruh kandidat sebelum penghapusan, hanya nama lab yang tepat.
    foreach ($name in $conflicts) {
        if (-not $Repair) {
            throw "Container $name sudah ada/memakai port. Gunakan -Repair bila container tersebut milik latihan Anda."
        }
        $metadataJson = Require-LabDocker @('inspect', $name)
        $metadata = @(ConvertFrom-Json -InputObject $metadataJson)[0]
        $image = [string]$metadata.Config.Image
        if ($image -notmatch '^(docker\.io/library/)?nginx(:|@)') {
            throw "STOP: $name memakai image $image. Script tidak menghapus container selain Nginx lab."
        }
        if ($name -notin @('cloudlab-site', 'cloudlab-nginx')) {
            $labLabel = $null
            if ($null -ne $metadata.Config.Labels) {
                $labLabel = $metadata.Config.Labels.PSObject.Properties['edu.cloud-services.lab']
            }
            if ($null -eq $labLabel -or $labLabel.Value -ne '04') {
                throw "STOP: $name tidak mempunyai label starter Lab 04; container tetap dipertahankan."
            }
        }
    }

    $imageCheck = Invoke-LabDocker @('image', 'inspect', 'nginx:alpine', '--format', '{{.Id}}')
    if ($imageCheck.Code -ne 0) {
        Write-Output 'Image belum tersedia; mengunduh nginx:alpine (memerlukan internet).'
        Write-Output (Require-LabDocker @('pull', 'nginx:alpine'))
    }
    foreach ($name in $conflicts) {
        Write-Output "REPAIR: membuat ulang container lab $name; file host tetap ada."
        Write-Output (Require-LabDocker @('rm', '-f', $name))
    }

    $runArguments = @(
        'run', '--name', $ContainerName, '-d',
        '-p', "127.0.0.1:${SitePort}:80",
        '--label', 'edu.cloud-services.lab=04',
        '--mount', $mountArgument, 'nginx:alpine'
    )
    Write-Output (Require-LabDocker $runArguments)
    $response = $null
    $requestError = ''
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$SitePort/" -UseBasicParsing -TimeoutSec 2
            break
        }
        catch {
            $requestError = $_.Exception.Message
            Start-Sleep -Milliseconds 250
        }
    }
    if ($null -eq $response -or $response.StatusCode -ne 200) {
        throw "HTTP belum 200: $requestError. Cek docker logs --tail 20 $ContainerName dan isi mount melalui docker exec."
    }
    Write-Output (Require-LabDocker @('inspect', '--format', '{{range .Mounts}}{{.Source}} -> {{.Destination}} RW={{.RW}}{{end}}', $ContainerName))
    Write-Output "HTTP $($response.StatusCode) OK"
    Write-Output "WEB: http://127.0.0.1:$SitePort/"
    Write-Output "Lanjutkan langkah lab dari root repo: $repoRoot"
}
catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
