#Requires -Version 5.1
<#
.SYNOPSIS
    Timer CLI Installer for Windows
.DESCRIPTION
    Installs Timer CLI on Windows. Downloads pre-built binary or builds from source if needed.
.EXAMPLE
    iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -BuildFromSource
#>

[CmdletBinding()]
param(
    [switch]$BuildFromSource,
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
# Helper Functions
# ============================================================================

function Write-Success { param($Message) Write-Host "✓ " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-Warn { param($Message) Write-Host "→ " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-Err { param($Message) Write-Host "✗ " -ForegroundColor Red -NoNewline; Write-Host $Message }
function Write-Info { param($Message) Write-Host "i " -ForegroundColor Cyan -NoNewline; Write-Host $Message }

function Show-Usage {
    @"
Timer CLI Installer for Windows

Usage:
    iwr -useb https://raw.githubusercontent.com/$Script:Repo/main/install.ps1 | iex
    .\install.ps1 [options]

Options:
    -BuildFromSource    Build from source instead of downloading binary
    -Help               Show this help

Environment variables:
    TIMER_CLI_INSTALL_DIR    Installation directory (default: ~/.local/bin)
    TIMER_CLI_BUILD_SOURCE   Set to 1 to build from source

Examples:
    # Install latest version
    iwr -useb https://raw.githubusercontent.com/$Script:Repo/main/install.ps1 | iex

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
        return $true
    }
    return $false
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
    
    $tempFile = "$env:TEMP\$Script:BinaryName.exe"
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
        
        if (-not (Test-Path $tempFile) -or (Get-Item $tempFile).Length -eq 0) {
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
    # Add tt alias to PowerShell profile
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
    
    $aliasLine = "Set-Alias -Name tt -Value timer_cli"
    
    # Only add if not already present
    $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch 'Set-Alias.*tt.*timer_cli') {
        Add-Content -Path $profilePath -Value "`n# Timer CLI shortcut`n$aliasLine"
        Write-Info "Added 'tt' alias to PowerShell profile"
    }
    
    # Set for current session
    Set-Alias -Name tt -Value timer_cli -Scope Global
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
    Write-Host "🕐 Timer CLI Installer for Windows" -ForegroundColor Cyan
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
        $version = Get-LatestVersion
        
        if ($version) {
            Write-Success "Found version: $version"
            $installed = Install-FromRelease -Version $version
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
    Write-Host "✅ Installation complete!" -ForegroundColor Green
    Write-Host ""
    
    Write-Success "Ready to use! Try: tt 5s `"Hello`""
    Write-Info "You may need to restart your terminal for changes to take effect."
    
    Write-Host ""
    Write-Host "Documentation: https://github.com/$Script:Repo#readme" -ForegroundColor Cyan
}

Main
