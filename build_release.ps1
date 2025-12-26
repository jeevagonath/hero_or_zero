Write-Host "Starting Release Build Process..." -ForegroundColor Cyan

# 0. Clean Build (Fix for missing plugins/cache issues)
Write-Host "Cleaning build cache..." -ForegroundColor Cyan
flutter clean
flutter pub get

# 1. Increment Version
$pubspecPath = "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    Write-Error "pubspec.yaml not found!"
    exit 1
}

$content = Get-Content $pubspecPath -Raw
$pattern = 'version: (\d+\.\d+\.\d+)\+(\d+)'

if ($content -match $pattern) {
    $version = $matches[1]
    $buildNumber = [int]$matches[2]
    $newBuildNumber = $buildNumber + 1
    
    $newVersionLine = "version: $version+$newBuildNumber"
    $newContent = $content -replace $pattern, $newVersionLine
    
    Set-Content -Path $pubspecPath -Value $newContent
    Write-Host "Updated version to $version+$newBuildNumber" -ForegroundColor Green
} else {
    Write-Error "Could not find version pattern in pubspec.yaml"
    exit 1
}

# 2. Build Release APK
Write-Host "Building Flutter APK (Release)..." -ForegroundColor Cyan
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Successful!" -ForegroundColor Green
    Write-Host "APK Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
} else {
    Write-Error "Flutter Build Failed!"
    exit $LASTEXITCODE
}
