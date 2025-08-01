# Helper script to copy the compiled Zig library to the Rust test directories
# Usage: .\scripts\copy-lib-for-tests.ps1

Write-Host "Copying zrraw library for Rust tests..." -ForegroundColor Blue

$RootDir = Split-Path $PSScriptRoot -Parent
$RustDir = Join-Path $RootDir "bindings\rust"

# Look for the DLL in both possible locations (bin and lib) and handle versioned files
$LibPath = $null
$SearchDirs = @(
    (Join-Path $RootDir "zig-out\bin"),
    (Join-Path $RootDir "zig-out\lib")
)

foreach ($SearchDir in $SearchDirs) {
    if (Test-Path $SearchDir) {
        $DllFiles = Get-ChildItem -Path $SearchDir -Name "zrraw*.dll" -ErrorAction SilentlyContinue
        if ($DllFiles) {
            $LibPath = Join-Path $SearchDir $DllFiles[0]
            Write-Host "Found library: $LibPath" -ForegroundColor Green
            break
        }
    }
}

if (-not $LibPath) {
    Write-Host "Error: No zrraw dll found in zig-out\bin or zig-out\lib" -ForegroundColor Red
    Write-Host "Please build the Zig library first with: zig build" -ForegroundColor Yellow
    Write-Host "Searched in:" -ForegroundColor Yellow
    foreach ($SearchDir in $SearchDirs) {
        Write-Host "  - $SearchDir" -ForegroundColor Yellow
        if (Test-Path $SearchDir) {
            Get-ChildItem $SearchDir -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    }
    exit 1
}

# Copy to target/debug/deps if it exists
$TargetDepsDir = Join-Path $RustDir "target\debug\deps"
if (Test-Path $TargetDepsDir) {
    Write-Host "Copying to target\debug\deps\ as zrraw.dll" -ForegroundColor Green
    Copy-Item $LibPath (Join-Path $TargetDepsDir "zrraw.dll")
    
    # Also copy to any existing test executable directories
    $TestExes = Get-ChildItem -Path $TargetDepsDir -Name "zrraw*" -File
    foreach ($TestExe in $TestExes) {
        $TestDir = Split-Path (Join-Path $TargetDepsDir $TestExe) -Parent
        Write-Host "Copying to $TestDir\ as zrraw.dll" -ForegroundColor Green
        Copy-Item $LibPath (Join-Path $TestDir "zrraw.dll")
    }
}

# Also copy to the current working directory as a fallback
Write-Host "Copying to Rust directory as zrraw.dll (fallback)" -ForegroundColor Green
Copy-Item $LibPath (Join-Path $RustDir "zrraw.dll")

Write-Host "✅ Library copied successfully!" -ForegroundColor Green
Write-Host "💡 You can now run: cargo test --workspace --features `"zrraw-sys/compile-from-source`"" -ForegroundColor Yellow
