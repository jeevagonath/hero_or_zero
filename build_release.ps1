Write-Host "Starting Release Build Process..." -ForegroundColor Cyan

# 1. Read Version from pubspec.yaml
$pubspecPath = "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    Write-Error "pubspec.yaml not found!"
    exit 1
}

$content = Get-Content $pubspecPath -Raw
$pattern = 'version: (\d+\.\d+\.\d+)\+(\d+)'

if ($content -match $pattern) {
    $versionName = $matches[1]
    $buildNumber = $matches[2]
    Write-Host "------------------------------------------------" -ForegroundColor Yellow
    Write-Host "   BUILDING VERSION: $versionName (Build $buildNumber)" -ForegroundColor Yellow
    Write-Host "------------------------------------------------" -ForegroundColor Yellow
} else {
    Write-Warning "Could not read version from pubspec.yaml"
}

# 2. Build Release APK
Write-Host "Building Flutter APK (Release)..." -ForegroundColor Cyan
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Successful!" -ForegroundColor Green
    Write-Host "Ver: $versionName+$buildNumber" -ForegroundColor Green
    Write-Host "APK Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
} else {
    Write-Error "Flutter Build Failed!"
    exit $LASTEXITCODE
}
