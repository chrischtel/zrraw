# Helper script to copy the compiled Zig library to the Rust test directories
# Usage: .\scripts\copy-lib-for-tests.ps1

Write-Host "Copying zrraw library for Rust tests..." -ForegroundColor Blue

$RootDir = Split-Path $PSScriptRoot -Parent
$LibPath = Join-Path $RootDir "zig-out\bin\zrraw.dll"
$RustDir = Join-Path $RootDir "bindings\rust"

if (-not (Test-Path $LibPath)) {
    Write-Host "Error: Library not found at $LibPath" -ForegroundColor Red
    Write-Host "Please build the Zig library first with: zig build" -ForegroundColor Yellow
    exit 1
}

# Copy to target/debug/deps if it exists
$TargetDepsDir = Join-Path $RustDir "target\debug\deps"
if (Test-Path $TargetDepsDir) {
    Write-Host "Copying zrraw.dll to target\debug\deps\" -ForegroundColor Green
    Copy-Item $LibPath $TargetDepsDir
    
    # Also copy to any existing test executable directories
    $TestExes = Get-ChildItem -Path $TargetDepsDir -Name "zrraw*" -File
    foreach ($TestExe in $TestExes) {
        $TestDir = Split-Path (Join-Path $TargetDepsDir $TestExe) -Parent
        Write-Host "Copying zrraw.dll to $TestDir\" -ForegroundColor Green
        Copy-Item $LibPath $TestDir
    }
}

# Also copy to the current working directory as a fallback
Write-Host "Copying zrraw.dll to Rust directory as fallback" -ForegroundColor Green
Copy-Item $LibPath $RustDir

Write-Host "✅ Library copied successfully!" -ForegroundColor Green
Write-Host "💡 You can now run: cargo test --workspace --features `"zrraw-sys/compile-from-source`"" -ForegroundColor Yellow
