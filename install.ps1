#Requires -Version 5.1
<#
.SYNOPSIS
    Terminal Timer (tt) CLI Installer for Windows
.DESCRIPTION
    Installs Terminal Timer (tt) CLI on Windows. Downloads pre-built binary or builds from source if needed.
.EXAMPLE
    iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -BuildFromSource
#>

[CmdletBinding()]
param(
    [switch]$BuildFromSource,
    [string]$Version,
    [switch]$Help
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Speeds up Invoke-WebRequest

$Script:Repo = "EricLBaker/rust_cli_timer"
$Script:BinaryName = "timer_cli"
$Script:InstallDir = "$env:USERPROFILE\.local\bin"
$Script:CargoBin = "$env:USERPROFILE\.cargo\bin"

# ============================================================================
# Helper Functions (Tokyo Night theme colors)
# ============================================================================

# Tokyo Night colors: Green #9ece6a, Yellow #e0af68, Pink #f7768e, Blue #7aa2f7, Purple #bb9af7
function Write-Success { param($Message) Write-Host "✓ " -ForegroundColor DarkGreen -NoNewline; Write-Host $Message }
function Write-Warn { param($Message) Write-Host "→ " -ForegroundColor DarkYellow -NoNewline; Write-Host $Message }
function Write-Err { param($Message) Write-Host "✗ " -ForegroundColor Magenta -NoNewline; Write-Host $Message }
function Write-Info { param($Message) Write-Host "i " -ForegroundColor Blue -NoNewline; Write-Host $Message }

function Show-Usage {
    @"
Terminal Timer (tt) CLI Installer for Windows

Usage:
    iwr -useb https://raw.githubusercontent.com/$Script:Repo/main/install.ps1 | iex
    .\install.ps1 [options]

Options:
    -Version VERSION    Install a specific version (e.g., v1.0.5)
    -BuildFromSource    Build from source instead of downloading binary
    -Help               Show this help

Environment variables:
    TIMER_CLI_INSTALL_DIR    Installation directory (default: ~/.local/bin)
    TIMER_CLI_BUILD_SOURCE   Set to 1 to build from source

Examples:
    # Install latest version
    iwr -useb https://raw.githubusercontent.com/$Script:Repo/main/install.ps1 | iex

    # Install specific version
    .\install.ps1 -Version v1.0.5

    # Build from source
    .\install.ps1 -BuildFromSource
"@
}

# ============================================================================
# Platform Detection
# ============================================================================

function Get-Platform {
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "x86" }
    return "windows-$arch"
}

# ============================================================================
# Version Resolution
# ============================================================================

function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Script:Repo/releases/latest" -UseBasicParsing
        return $response.tag_name
    } catch {
        # Fallback: try to scrape releases page
        try {
            $html = Invoke-WebRequest -Uri "https://github.com/$Script:Repo/releases" -UseBasicParsing
            if ($html.Content -match '/releases/tag/([^"'']+)') {
                return $matches[1]
            }
        } catch {}
    }
    return $null
}

# ============================================================================
# PATH Management
# ============================================================================

function Add-ToUserPath {
    param([string]$Directory)
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$Directory*") {
        $newPath = "$Directory;$currentPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        # Also update current session
        $env:Path = "$Directory;$env:Path"
        Write-Success "Added $Directory to PATH"
    }
}

function Test-InPath {
    param([string]$Directory)
    return $env:Path -like "*$Directory*"
}

# ============================================================================
# Rust Installation
# ============================================================================

function Test-RustInstalled {
    return (Get-Command cargo -ErrorAction SilentlyContinue) -ne $null
}

function Install-Rust {
    if (Test-RustInstalled) {
        Write-Success "Rust/Cargo already installed"
        return
    }
    
    Write-Warn "Installing Rust via rustup..."
    
    $rustupInit = "$env:TEMP\rustup-init.exe"
    Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $rustupInit -UseBasicParsing
    
    # Run rustup-init with default options
    & $rustupInit -y --no-modify-path
    
    Remove-Item $rustupInit -Force -ErrorAction SilentlyContinue
    
    # Add cargo to PATH
    Add-ToUserPath $Script:CargoBin
    
    # Refresh environment for current session
    $env:Path = "$Script:CargoBin;$env:Path"
    
    Write-Success "Rust installed"
}

# ============================================================================
# Installation Methods
# ============================================================================

function Install-FromRelease {
    param([string]$Version)
    
    $platform = Get-Platform
    $downloadUrl = "https://github.com/$Script:Repo/releases/download/$Version/$Script:BinaryName-$platform.exe"
    
    Write-Warn "Downloading $Script:BinaryName ($Version)..."
    Write-Info "URL: $downloadUrl"
    
    $tempFile = "$env:TEMP\$Script:BinaryName.exe"
    
    try {
        # Use -MaximumRedirection to follow GitHub's redirects
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing -MaximumRedirection 5
        
        if (-not (Test-Path $tempFile) -or (Get-Item $tempFile).Length -lt 1000) {
            Write-Err "Download failed or file too small"
            return $false
        }
        
        # Create install directory
        if (-not (Test-Path $Script:InstallDir)) {
            New-Item -ItemType Directory -Path $Script:InstallDir -Force | Out-Null
        }
        
        # Move binary
        $targetPath = Join-Path $Script:InstallDir "$Script:BinaryName.exe"
        Move-Item -Path $tempFile -Destination $targetPath -Force
        
        Write-Success "Installed to $targetPath"
        return $true
    } catch {
        Write-Err "Download error: $_"
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Install-FromSource {
    Write-Warn "Building from source..."
    
    if (-not (Test-RustInstalled)) {
        Install-Rust
    }
    
    Write-Warn "Running: cargo install --git https://github.com/$Script:Repo.git"
    & cargo install --git "https://github.com/$Script:Repo.git"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo install failed"
    }
    
    Write-Success "Built and installed via Cargo"
}

function Add-Alias {
    # Add tt alias and PATH to PowerShell profile
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent
    
    # Create profile directory if needed
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # Create profile if needed
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    
    $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { $content = "" }
    
    $modified = $false
    
    # Add PATH entry if not present
    $pathLine = "`$env:Path = `"$Script:InstallDir;`$env:Path`""
    if ($content -notmatch [regex]::Escape($Script:InstallDir)) {
        Add-Content -Path $profilePath -Value "`n# Terminal Timer (tt) CLI PATH`n$pathLine"
        Write-Info "Added $Script:InstallDir to PowerShell profile PATH"
        $modified = $true
    }
    
    # Add alias if not present
    $aliasLine = "Set-Alias -Name tt -Value timer_cli"
    if ($content -notmatch 'Set-Alias.*tt.*timer_cli') {
        Add-Content -Path $profilePath -Value "`n# Terminal Timer (tt) CLI shortcut`n$aliasLine"
        Write-Info "Added 'tt' alias to PowerShell profile"
        $modified = $true
    }
    
    # Set for current session
    $env:Path = "$Script:InstallDir;$env:Path"
    Set-Alias -Name tt -Value timer_cli -Scope Global
    
    if ($modified) {
        Write-Info "Profile updated: $profilePath"
    }
}

# ============================================================================
# Main
# ============================================================================

function Main {
    if ($Help) {
        Show-Usage
        return
    }
    
    Write-Host ""
    Write-Host "=== Terminal Timer (tt) CLI Installer for Windows ===" -ForegroundColor Cyan
    Write-Host ""
    
    $platform = Get-Platform
    Write-Success "Detected: $platform"
    
    # Create install directory
    if (-not (Test-Path $Script:InstallDir)) {
        New-Item -ItemType Directory -Path $Script:InstallDir -Force | Out-Null
    }
    
    # Add to PATH
    Add-ToUserPath $Script:InstallDir
    
    $installed = $false
    
    if (-not $BuildFromSource) {
        Write-Warn "Checking for pre-built release..."
        
        # Use specified version or get latest
        if ($Version) {
            $targetVersion = $Version
            Write-Info "Installing specific version: $targetVersion"
        } else {
            $targetVersion = Get-LatestVersion
        }
        
        if ($targetVersion) {
            Write-Success "Found version: $targetVersion"
            $installed = Install-FromRelease -Version $targetVersion
            if (-not $installed) {
                Write-Warn "Pre-built binary not available for $platform"
            }
        } else {
            Write-Warn "No releases found"
        }
    }
    
    if (-not $installed) {
        Write-Warn "Will build from source instead..."
        Write-Host ""
        Install-Rust
        Install-FromSource
    }
    
    # Add tt alias
    Add-Alias
    
    Write-Host ""
    Write-Host "[OK] Installation complete!" -ForegroundColor Green
    Write-Host ""
    
    Write-Success "Ready to use! Try: tt 5s `"Hello`""
    Write-Info "You may need to restart your terminal for changes to take effect."
    
    Write-Host ""
    Write-Host "Documentation: https://github.com/$Script:Repo#readme" -ForegroundColor Cyan
}

Main
