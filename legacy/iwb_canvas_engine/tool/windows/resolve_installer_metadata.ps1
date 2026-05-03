Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9A-Za-z\.\+\-]+)\s*$') {
  throw "Could not resolve package version from pubspec.yaml"
}

$packageVersion = $Matches[1]
$installerVersion = $packageVersion.Split('+')[0]
$safeVersion = $packageVersion -replace '[^0-9A-Za-z\.\-]+', '-'
$workspace = if ([string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
  (Get-Location).Path
} else {
  $env:GITHUB_WORKSPACE
}
$outputDir = Join-Path $workspace 'build\installer'

if ([string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
  throw "GITHUB_OUTPUT is not set."
}

Add-Content -Path $env:GITHUB_OUTPUT -Value "package_version=$packageVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "installer_version=$installerVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "safe_version=$safeVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "output_dir=$outputDir"
