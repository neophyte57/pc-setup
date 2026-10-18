<#
.SYNOPSIS
    Installs Chocolatey packages from a package.config file, checking trust status via choco info.

.DESCRIPTION
    Reads a Chocolatey package.config XML file and installs packages after verifying
    their trust status using "choco info". Only packages with trusted status will be installed.

.PARAMETER ConfigPath
    Path to the package.config file. Defaults to "packages.config" in current directory.

.EXAMPLE
    .\Install-TrustedChocolateyPackages.ps1 -ConfigPath "C:\path\to\packages.config"
#>

#
# Assistance from Claude Sonnet 4.5 
#
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "packages.config"
)

# Check if config file exists
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Error "Chocolatey is not installed. Please install Chocolatey first."
    exit 1
}

# Load the XML file
try {
    [xml]$config = Get-Content $ConfigPath
}
catch {
    Write-Error "Failed to parse XML file: $_"
    exit 1
}

# Get all packages from config
$packages = $config.packages.package

if ($packages.Count -eq 0) {
    Write-Warning "No packages found in $ConfigPath"
    exit 0
}

# Function to check if a package is trusted using choco info
function Test-PackageTrusted {
    param([string]$PackageId)
    
    $chocoInfo = choco info $PackageId 2>&1
    
    $infoText = $chocoInfo -join "`n"    
    Write-Debug $infoText

    # Check for trust indicators in choco info output
    if ($infoText -match "Package approved as a trusted package on") {
        return $true
    }
    
    # Versus simply "Package approved by mkevenaar on Apr 24 2020 19:00:16."
    return $false
}

Write-Host "Checking trust status for packages..." -ForegroundColor Yellow

$trustedPackages = @()
$untrustedCount = 0

# Check trust status for each package
foreach ($package in $packages) {
    $packageId = $package.id
    
    Write-Host "Checking: $packageId" -ForegroundColor Gray
    
    if (Test-PackageTrusted -PackageId $packageId) {
        Write-Host "  [Trusted]" -ForegroundColor Green
        $trustedPackages += $package
    }
    else {
        Write-Host "  [Not Trusted]" -ForegroundColor Red
        $untrustedCount++
    }
}

Write-Host "`nFound $($trustedPackages.Count) trusted package(s) to install:" -ForegroundColor Green
Write-Host "Found $untrustedCount untrusted package(s) (skipped):" -ForegroundColor Red

if ($trustedPackages.Count -eq 0) {
    Write-Warning "No trusted packages found"
    exit 0
}

# Install each trusted package
foreach ($package in $trustedPackages) {
    $packageId = $package.id
    $version = $package.version
    
    Write-Host "`nInstalling: $packageId" -ForegroundColor Cyan
    
    if ($version) {
        choco install $packageId --version=$version -y
    }
    else {
        choco install $packageId -y
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to install package: $packageId"
    }
}

Write-Host "`nInstallation complete!" -ForegroundColor Green
