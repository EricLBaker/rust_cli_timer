#Requires -Version 5.1
<#
.SYNOPSIS
    Timer CLI Uninstaller for Windows
.DESCRIPTION
    Uninstalls Timer CLI from Windows.
.EXAMPLE
    iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/uninstall.ps1 | iex
.EXAMPLE
    .\uninstall.ps1 -RemoveRust
#>

[CmdletBinding()]
param(
    [switch]$RemoveRust,
    [switch]$RemoveData,
    [switch]$Help
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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
Timer CLI Uninstaller for Windows

Usage:
    iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/uninstall.ps1 | iex
    .\uninstall.ps1 [options]

Options:
    -RemoveRust     Also uninstall Rust (if installed by the installer)
    -RemoveData     Remove app data without prompting
    -Help           Show this help

What this removes:
    • timer_cli.exe from ~/.local/bin and ~/.cargo/bin
    • PATH entries added by the installer
    • Optionally: Rust installation (with -RemoveRust)
    • Optionally: timer_cli data/history files

What this does NOT remove:
    • Any other tools or dependencies
"@
}

# ============================================================================
# PATH Management
# ============================================================================

function Remove-FromUserPath {
    param([string]$Directory)
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -like "*$Directory*") {
        $paths = $currentPath -split ";" | Where-Object { $_ -ne $Directory -and $_ -ne "" }
        $newPath = $paths -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Success "Removed $Directory from PATH"
        return $true
    }
    return $false
}

# ============================================================================
# Binary Removal
# ============================================================================

function Remove-Binary {
    $removed = $false
    
    # Check install dir
    $binaryPath = Join-Path $Script:InstallDir "$Script:BinaryName.exe"
    if (Test-Path $binaryPath) {
        Remove-Item $binaryPath -Force
        Write-Success "Removed $binaryPath"
        $removed = $true
    }
    
    # Check cargo bin
    $cargoBinaryPath = Join-Path $Script:CargoBin "$Script:BinaryName.exe"
    if (Test-Path $cargoBinaryPath) {
        Remove-Item $cargoBinaryPath -Force
        Write-Success "Removed $cargoBinaryPath"
        $removed = $true
    }
    
    # Try cargo uninstall
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        try {
            & cargo uninstall $Script:BinaryName 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Uninstalled via cargo"
                $removed = $true
            }
        } catch {}
    }
    
    if (-not $removed) {
        Write-Warn "No $Script:BinaryName binary found to remove"
    }
}

# ============================================================================
# Rust Removal
# ============================================================================

function Remove-Rust {
    $rustupPath = Join-Path $Script:CargoBin "rustup.exe"
    
    if (Test-Path $rustupPath) {
        Write-Warn "Removing Rust installation..."
        & $rustupPath self uninstall -y
        Write-Success "Rust uninstalled"
    } elseif (Get-Command rustup -ErrorAction SilentlyContinue) {
        Write-Warn "Removing Rust installation..."
        & rustup self uninstall -y
        Write-Success "Rust uninstalled"
    } else {
        Write-Warn "Rust/rustup not found, skipping"
    }
}

# ============================================================================
# App Data Removal
# ============================================================================

function Remove-AppData {
    param([bool]$Force = $false)
    
    $dataLocations = @(
        "$env:USERPROFILE\.timer_cli",
        "$env:LOCALAPPDATA\timer_cli",
        "$env:APPDATA\timer_cli"
    )
    
    $found = $dataLocations | Where-Object { Test-Path $_ }
    
    if ($found) {
        $shouldRemove = $Force
        
        if (-not $Force) {
            Write-Host ""
            Write-Info "Found timer_cli data files. Remove them? (y/N)"
            $response = Read-Host
            $shouldRemove = $response -match '^[Yy]'
        }
        
        if ($shouldRemove) {
            foreach ($loc in $found) {
                Remove-Item $loc -Recurse -Force
                Write-Success "Removed $loc"
            }
        } else {
            Write-Info "Keeping data files"
        }
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
    Write-Host "🕐 Timer CLI Uninstaller for Windows" -ForegroundColor Cyan
    Write-Host ""
    
    # Remove binary
    Write-Warn "Removing timer_cli binary..."
    Remove-Binary
    
    # Remove from PATH
    Write-Warn "Cleaning PATH..."
    Remove-FromUserPath $Script:InstallDir
    
    # Optionally remove Rust
    if ($RemoveRust) {
        Remove-Rust
        Remove-FromUserPath $Script:CargoBin
    }
    
    # Handle app data
    Remove-AppData -Force:$RemoveData
    
    Write-Host ""
    Write-Host "✅ Uninstallation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Info "You may need to restart your terminal for PATH changes to take effect."
    
    if (-not $RemoveRust) {
        Write-Host ""
        Write-Info "Rust was not removed. To remove it, run:"
        Write-Host "     rustup self uninstall" -ForegroundColor Cyan
        Write-Host "  Or re-run with: .\uninstall.ps1 -RemoveRust" -ForegroundColor Cyan
    }
}

Main
