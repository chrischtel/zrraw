# Version management script for zrraw (PowerShell version)
# Usage: .\scripts\version.ps1 [patch|minor|major|prerelease] [prerelease-type]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("patch", "minor", "major", "prerelease")]
    [string]$BumpType,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("alpha", "beta", "rc")]
    [string]$PrereleaseType
)

function Print-Usage {
    Write-Host "Usage: .\scripts\version.ps1 [patch|minor|major|prerelease] [prerelease-type]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  patch       Bump patch version (1.0.0 -> 1.0.1)"
    Write-Host "  minor       Bump minor version (1.0.0 -> 1.1.0)"
    Write-Host "  major       Bump major version (1.0.0 -> 2.0.0)"
    Write-Host "  prerelease  Bump prerelease version"
    Write-Host ""
    Write-Host "Prerelease types (for prerelease command):"
    Write-Host "  alpha       Create/bump alpha version (1.0.0 -> 1.0.1-alpha.1)"
    Write-Host "  beta        Create/bump beta version"
    Write-Host "  rc          Create/bump release candidate"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\scripts\version.ps1 patch                    # 1.0.0 -> 1.0.1"
    Write-Host "  .\scripts\version.ps1 minor                    # 1.0.0 -> 1.1.0"
    Write-Host "  .\scripts\version.ps1 prerelease alpha         # 1.0.0 -> 1.0.1-alpha.1"
    Write-Host "  .\scripts\version.ps1 prerelease beta          # 1.0.1-alpha.1 -> 1.0.1-beta.1"
}

function Get-CurrentVersion {
    $cargoToml = Get-Content ".\bindings\rust\zrraw\Cargo.toml"
    $versionLine = $cargoToml | Where-Object { $_ -match '^version = "(.+)"' }
    if ($versionLine) {
        return $Matches[1]
    }
    throw "Could not find version in Cargo.toml"
}

function Parse-Version {
    param([string]$Version)
    
    if ($Version -match '^(\d+)\.(\d+)\.(\d+)(-([a-zA-Z]+)\.(\d+))?$') {
        return @{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
            PrereleaseType = $Matches[5]
            PrereleaseNum = if ($Matches[6]) { [int]$Matches[6] } else { 0 }
        }
    } else {
        throw "Invalid version format: $Version"
    }
}

function Update-FileVersion {
    param([string]$FilePath, [string]$NewVersion)
    
    $content = Get-Content $FilePath
    $updated = $content -replace '^version = ".*"', "version = `"$NewVersion`""
    $updated = $updated -replace '\.version = ".*"', ".version = `"$NewVersion`""
    Set-Content -Path $FilePath -Value $updated
}

function Bump-Version {
    param([string]$BumpType, [string]$PrereleaseType)
    
    try {
        $currentVersion = Get-CurrentVersion
        Write-Host "Current version: $currentVersion" -ForegroundColor Blue
        
        $parsed = Parse-Version $currentVersion
        
        switch ($BumpType) {
            "patch" {
                if ($parsed.PrereleaseType) {
                    # Remove prerelease suffix
                    $newVersion = "$($parsed.Major).$($parsed.Minor).$($parsed.Patch)"
                } else {
                    $newVersion = "$($parsed.Major).$($parsed.Minor).$($parsed.Patch + 1)"
                }
            }
            "minor" {
                $newVersion = "$($parsed.Major).$($parsed.Minor + 1).0"
            }
            "major" {
                $newVersion = "$($parsed.Major + 1).0.0"
            }
            "prerelease" {
                if (-not $PrereleaseType) {
                    Write-Host "Error: Prerelease type required for prerelease bump" -ForegroundColor Red
                    Print-Usage
                    exit 1
                }
                
                if ($parsed.PrereleaseType -and $parsed.PrereleaseType -eq $PrereleaseType) {
                    # Same prerelease type, bump number
                    $newVersion = "$($parsed.Major).$($parsed.Minor).$($parsed.Patch)-$PrereleaseType.$($parsed.PrereleaseNum + 1)"
                } elseif ($parsed.PrereleaseType) {
                    # Different prerelease type, reset to 1
                    $newVersion = "$($parsed.Major).$($parsed.Minor).$($parsed.Patch)-$PrereleaseType.1"
                } else {
                    # First prerelease
                    $newVersion = "$($parsed.Major).$($parsed.Minor).$($parsed.Patch + 1)-$PrereleaseType.1"
                }
            }
        }
        
        Write-Host "New version: $newVersion" -ForegroundColor Green
        
        # Update files
        Write-Host "Updating Cargo.toml files..." -ForegroundColor Yellow
        Update-FileVersion ".\bindings\rust\zrraw\Cargo.toml" $newVersion
        Update-FileVersion ".\bindings\rust\zrraw-sys\Cargo.toml" $newVersion
        
        Write-Host "Updating build.zig.zon..." -ForegroundColor Yellow
        Update-FileVersion ".\build.zig.zon" $newVersion
        
        Write-Host "✅ Version updated to $newVersion" -ForegroundColor Green
        Write-Host "💡 Tip: Commit and push to main to automatically create a release" -ForegroundColor Yellow
        
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Validate parameters
if ($BumpType -eq "prerelease" -and -not $PrereleaseType) {
    Write-Host "Error: Prerelease type required when using 'prerelease' bump type" -ForegroundColor Red
    Print-Usage
    exit 1
}

# Run the version bump
Bump-Version $BumpType $PrereleaseType
