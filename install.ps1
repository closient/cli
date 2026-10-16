# Install the closient CLI on Windows.
#
#   irm https://www.closient.com/cli/install.ps1 | iex
#
# Downloads the latest release from https://github.com/closient/cli, verifies
# it against the release's SHA256SUMS, and installs closient.exe to
# %LOCALAPPDATA%\Programs\closient. No administrator rights are needed; nothing
# is installed if any step fails.
#
# Environment:
#   CLOSIENT_INSTALL_DIR   install here instead
#   CLOSIENT_VERSION       install this version (e.g. 0.1.0) instead of the latest
#   CLOSIENT_RELEASES_URL  release host (default https://github.com/closient/cli/releases)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Install-Closient {
    $releases = if ($env:CLOSIENT_RELEASES_URL) { $env:CLOSIENT_RELEASES_URL } else { 'https://github.com/closient/cli/releases' }
    $installDir = if ($env:CLOSIENT_INSTALL_DIR) { $env:CLOSIENT_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\closient' }
    $version = if ($env:CLOSIENT_VERSION) { $env:CLOSIENT_VERSION.TrimStart('v') } else { '' }

    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
    # ARM64 Windows runs the x86_64 build under emulation.
    if ($arch -ne 'AMD64' -and $arch -ne 'ARM64') { throw "closient-install: unsupported architecture: $arch" }
    $target = 'x86_64-pc-windows-msvc'

    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("closient-install-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        $sumsUrl = if ($version) { "$releases/download/v$version/SHA256SUMS" } else { "$releases/latest/download/SHA256SUMS" }
        $sumsPath = Join-Path $work 'SHA256SUMS'
        Invoke-WebRequest -UseBasicParsing -Uri $sumsUrl -OutFile $sumsPath

        $pattern = "^([0-9a-f]{64})  (closient-(\S+)-$([regex]::Escape($target))\.zip)$"
        $match = Get-Content $sumsPath | ForEach-Object { [regex]::Match($_, $pattern) } | Where-Object { $_.Success } | Select-Object -First 1
        if (-not $match) { throw "closient-install: no $target build in $sumsUrl" }
        $expected = $match.Groups[1].Value
        $archive = $match.Groups[2].Value
        $resolved = $match.Groups[3].Value

        Write-Host "closient-install: downloading closient $resolved for $target"
        $archivePath = Join-Path $work $archive
        Invoke-WebRequest -UseBasicParsing -Uri "$releases/download/v$resolved/$archive" -OutFile $archivePath

        $actual = (Get-FileHash -Algorithm SHA256 -Path $archivePath).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "closient-install: checksum mismatch for $archive (expected $expected, got $actual); nothing was installed"
        }

        Expand-Archive -Path $archivePath -DestinationPath $work
        $binary = Join-Path $work "closient-$resolved-$target\closient.exe"
        if (-not (Test-Path $binary)) { throw "closient-install: $archive does not contain closient.exe" }

        New-Item -ItemType Directory -Force -Path $installDir | Out-Null
        $destination = Join-Path $installDir 'closient.exe'
        # A running closient.exe cannot be overwritten, but it can be renamed.
        if (Test-Path $destination) {
            $aside = "$destination.old"
            Remove-Item -Force $aside -ErrorAction SilentlyContinue
            Move-Item -Force $destination $aside
        }
        Copy-Item $binary $destination
        Write-Host "closient-install: installed closient $resolved to $destination"

        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $entries = if ($userPath) { $userPath.Split(';') } else { @() }
        if ($entries -notcontains $installDir) {
            $newPath = (@($entries | Where-Object { $_ }) + $installDir) -join ';'
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            Write-Host "closient-install: added $installDir to your user PATH; open a new terminal to use it"
        }
        Write-Host "closient-install: run 'closient --help' to get started, and 'closient update' to upgrade later"
    }
    finally {
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
    }
}

Install-Closient
