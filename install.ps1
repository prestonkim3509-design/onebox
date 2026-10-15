# OneBox installer for Windows. Paste this line into PowerShell:
#   irm https://raw.githubusercontent.com/prestonkim3509-design/onebox/updates/install.ps1 | iex
#
# OneBox runs on the standard Electron program, unmodified, which Windows Smart App
# Control already trusts. This puts that program in %LOCALAPPDATA%\OneBox\app, adds the
# OneBox starter, downloads the newest OneBox code, and makes desktop and Start menu
# icons. Running it again repairs or updates the install. Saved lives and settings
# (in %APPDATA%\OneBox) are never touched.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Feed = 'https://raw.githubusercontent.com/prestonkim3509-design/onebox/updates'
if ($env:ONEBOX_FEED_BASE) { $Feed = $env:ONEBOX_FEED_BASE }
$ElectronVersion = '32.2.5'
$ElectronUrl = "https://github.com/electron/electron/releases/download/v$ElectronVersion/electron-v$ElectronVersion-win32-x64.zip"
if ($env:ONEBOX_ELECTRON_URL) { $ElectronUrl = $env:ONEBOX_ELECTRON_URL }

$Root = Join-Path $env:LOCALAPPDATA 'OneBox'
$App = Join-Path $Root 'app'
$Versions = Join-Path $Root 'versions'
$Exe = Join-Path $App 'OneBox.exe'
$Starter = Join-Path $App 'resources\app'

Write-Host ''
Write-Host 'Installing OneBox...' -ForegroundColor Cyan
Get-Process -Name OneBox -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
New-Item -ItemType Directory -Force -Path $Root | Out-Null
New-Item -ItemType Directory -Force -Path $Versions | Out-Null

# 1. The app engine: the standard Electron program, renamed to OneBox.exe.
$stamp = Join-Path $App 'engine-version.txt'
$have = ''
if (Test-Path $stamp) { $have = (Get-Content $stamp -Raw).Trim() }
if (-not (Test-Path $Exe) -or $have -ne $ElectronVersion) {
  Write-Host 'Downloading the app engine (about 110 MB, one time only)...'
  $zip = Join-Path $env:TEMP "onebox-engine-$ElectronVersion.zip"
  Invoke-WebRequest -UseBasicParsing -Uri $ElectronUrl -OutFile $zip
  if (Test-Path $App) { Remove-Item $App -Recurse -Force }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $App)
  Remove-Item $zip -Force
  Rename-Item -Path (Join-Path $App 'electron.exe') -NewName 'OneBox.exe'
  Remove-Item (Join-Path $App 'resources\default_app.asar') -Force -ErrorAction SilentlyContinue
  Set-Content -Path $stamp -Value $ElectronVersion
}

# 2. The OneBox starter.
New-Item -ItemType Directory -Force -Path $Starter | Out-Null
foreach ($f in @('package.json', 'boot.js', 'icon.png', 'icon.ico')) {
  Invoke-WebRequest -UseBasicParsing -Uri "$Feed/shell/$f" -OutFile (Join-Path $Starter $f)
}

# 3. The newest OneBox code.
$info = Invoke-RestMethod -UseBasicParsing -Uri "$Feed/core.json?t=$(Get-Random)"
$dest = Join-Path $Versions $info.file
if (-not (Test-Path $dest)) {
  Write-Host "Downloading OneBox $($info.version)..."
  $part = "$dest.download"
  Invoke-WebRequest -UseBasicParsing -Uri "$Feed/$($info.file)" -OutFile $part
  $hash = (Get-FileHash -Path $part -Algorithm SHA512).Hash.ToLower()
  if ($hash -ne ([string]$info.sha512).ToLower()) {
    Remove-Item $part -Force
    throw 'The download was damaged. Paste the install line again.'
  }
  Move-Item -Path $part -Destination $dest -Force
}
Get-ChildItem $Versions -Filter '*.bad' -ErrorAction SilentlyContinue | Remove-Item -Force

# 4. Desktop and Start menu icons.
try {
  $ws = New-Object -ComObject WScript.Shell
  $icon = Join-Path $Starter 'icon.ico'
  $links = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'OneBox.lnk'),
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\OneBox.lnk')
  )
  foreach ($lnk in $links) {
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = $Exe
    $s.WorkingDirectory = $App
    $s.IconLocation = "$icon,0"
    $s.Description = 'OneBox'
    $s.Save()
  }
} catch {
  Write-Host "Could not make the desktop icon. Open OneBox from $Exe" -ForegroundColor Yellow
}

Write-Host "OneBox $($info.version) is installed. Opening it now." -ForegroundColor Green
if (-not $env:ONEBOX_NO_START) { Start-Process -FilePath $Exe }
