param(
  [Parameter(Mandatory = $true)]
  [string] $InstallerVersion,

  [Parameter(Mandatory = $true)]
  [string] $OutputDir,

  [Parameter(Mandatory = $true)]
  [string] $SafeVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspace = if ([string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
  (Get-Location).Path
} else {
  $env:GITHUB_WORKSPACE
}
$sourceDir = Join-Path $workspace 'example\build\windows\x64\runner\Release'
$installerScript = Join-Path $workspace 'tool\windows\example_installer.iss'

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' `
  "/DMyAppVersion=$InstallerVersion" `
  "/DMyOutputDir=$OutputDir" `
  "/DMyOutputBaseFilename=iwb_canvas_engine_example_setup_$SafeVersion" `
  "/DMySourceDir=$sourceDir" `
  $installerScript
