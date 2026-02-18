<#
.SYNOPSIS
    Build and push multi-platform Docker images to Azure Container Registry.

.DESCRIPTION
    Builds frontend and backend images for linux/amd64 and linux/arm64
    using docker buildx (default) or directly on ACR via 'az acr build' (-UseAcrBuild).

    Use -UseAcrBuild when local QEMU cross-compilation is unreliable (e.g. ARM host
    building AMD64 images). ACR Tasks run on cloud-hosted AMD64 agents, avoiding QEMU
    entirely. Each platform is built as a separate tagged image and a manifest list is
    created so the combined tag resolves multi-arch as usual.

.PARAMETER AcrLoginServer
    ACR login server hostname (e.g. myacr.azurecr.io).
    Defaults to ACR_LOGIN_SERVER env var.

.PARAMETER AcrName
    ACR resource name used for 'az acr login' / 'az acr build'.
    Defaults to ACR_NAME env var.

.PARAMETER Tag
    Image tag. Defaults to 'latest'.

.PARAMETER Services
    Which services to build. Accepts: 'backend', 'frontend', 'all'. Defaults to 'all'.

.PARAMETER SkipLogin
    Skip 'az acr login' (useful when already authenticated).

.PARAMETER UseAcrBuild
    Build images directly on ACR using 'az acr build' instead of local docker buildx.
    Avoids QEMU issues when cross-compiling on ARM hosts. Requires Azure CLI.

.PARAMETER AcrPlatforms
    Comma-separated platforms to build when using -UseAcrBuild.
    Defaults to 'linux/amd64,linux/arm64'. Set to 'linux/amd64' for a faster single-arch build.

.EXAMPLE
    .\scripts\docker-build.ps1
    .\scripts\docker-build.ps1 -AcrLoginServer myacr.azurecr.io -Tag v1.2.3
    .\scripts\docker-build.ps1 -Services backend -Tag $(git rev-parse --short HEAD)
    .\scripts\docker-build.ps1 -UseAcrBuild
    .\scripts\docker-build.ps1 -UseAcrBuild -AcrPlatforms linux/amd64 -Services backend
#>

[CmdletBinding()]
param(
    [string]$AcrLoginServer = $env:ACR_LOGIN_SERVER,
    [string]$AcrName        = $env:ACR_NAME,
    [string]$Tag            = "latest",
    [ValidateSet("backend", "frontend", "all")]
    [string]$Services       = "all",
    [switch]$SkipLogin,

    # ACR-native build options (avoids local QEMU)
    [switch]$UseAcrBuild,
    [string]$AcrPlatforms   = "linux/amd64,linux/arm64"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Resolve root of the repo ────────────────────────────────────────────────
$repoRoot = Split-Path -Parent $PSScriptRoot

# ── Validate required parameters ────────────────────────────────────────────
if (-not $AcrLoginServer) {
    Write-Error "ACR login server not set. Pass -AcrLoginServer or set ACR_LOGIN_SERVER env var."
}
if (-not $AcrName) {
    # Derive from login server if possible (myacr.azurecr.io → myacr)
    if ($AcrLoginServer -match "^([^.]+)\.azurecr\.io$") {
        $AcrName = $Matches[1]
        Write-Host "Derived ACR name: $AcrName" -ForegroundColor DarkGray
    } else {
        Write-Error "ACR name not set. Pass -AcrName or set ACR_NAME env var."
    }
}

$platforms = "linux/amd64,linux/arm64"

$images = @{
    backend  = "$AcrLoginServer/ai-app-backend:$Tag"
    frontend = "$AcrLoginServer/ai-app-frontend:$Tag"
}

# ── Helper ───────────────────────────────────────────────────────────────────
function Write-Step([string]$msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Invoke-Cmd([string]$cmd) {
    Write-Host "  $cmd" -ForegroundColor DarkGray
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $cmd" }
}

# ── Step 1: Setup builder (skipped for ACR builds) ──────────────────────────
if ($UseAcrBuild) {
    Write-Host "`n==> Using ACR build mode (az acr build) — local QEMU/buildx not required" -ForegroundColor Cyan
    Write-Host "  Platforms : $AcrPlatforms" -ForegroundColor DarkGray
} else {
    Write-Step "Ensuring buildx builder (multi-platform)"
    $builderName = "multiarch-builder"
    $existingBuilders = (docker buildx ls 2>&1) | Out-String
    if ($existingBuilders -notmatch $builderName) {
        Invoke-Cmd "docker buildx create --name $builderName --driver docker-container --bootstrap --use"
    } else {
        Invoke-Cmd "docker buildx use $builderName"
        Write-Host "  Builder '$builderName' already exists." -ForegroundColor DarkGray
    }
}

# ── Step 2: Login to ACR ─────────────────────────────────────────────────────
if (-not $SkipLogin) {
    Write-Step "Logging in to ACR: $AcrLoginServer"
    Invoke-Cmd "az acr login --name $AcrName"
} else {
    Write-Host "`n==> Skipping ACR login (-SkipLogin)" -ForegroundColor Yellow
}

# ── Step 3: Build and push ───────────────────────────────────────────────────

# --- Local buildx build (default) -------------------------------------------
function Build-And-Push([string]$service, [string]$context, [string]$dockerfile, [string]$image, [string]$target = "") {
    Write-Step "Building & pushing $service  →  $image"
    Write-Host "  Platforms : $platforms" -ForegroundColor DarkGray
    Write-Host "  Context   : $context" -ForegroundColor DarkGray
    Write-Host "  Dockerfile: $dockerfile" -ForegroundColor DarkGray

    $targetFlag = if ($target) { "--target $target" } else { "" }

    Invoke-Cmd (
        "docker buildx build " +
        "--platform $platforms " +
        "--file `"$dockerfile`" " +
        $targetFlag + " " +
        "--tag `"$image`" " +
        "--push " +
        "`"$context`""
    )

    Write-Host "  Pushed: $image" -ForegroundColor Green
}

# --- ACR-native build (avoids local QEMU) -----------------------------------
function Build-And-Push-Acr([string]$service, [string]$context, [string]$dockerfile, [string]$imageName, [string]$target = "") {
    $platformList = $AcrPlatforms -split ","

    Write-Step "Building & pushing $service via ACR build  →  $AcrLoginServer/$imageName`:$Tag"
    Write-Host "  Platforms : $AcrPlatforms" -ForegroundColor DarkGray
    Write-Host "  Context   : $context" -ForegroundColor DarkGray
    Write-Host "  Dockerfile: $dockerfile" -ForegroundColor DarkGray

    $targetFlag = if ($target) { "--target $target" } else { "" }
    $platformTags = @()

    foreach ($plat in $platformList) {
        # linux/amd64 → amd64,  linux/arm64 → arm64
        $platSuffix = ($plat -replace "linux/", "").Trim()
        $platTag    = "$imageName`:$Tag-$platSuffix"
        $platformTags += "$AcrLoginServer/$platTag"

        Write-Host "`n  Building platform: $plat  →  $platTag" -ForegroundColor DarkGray
        Invoke-Cmd (
            "az acr build " +
            "--registry `"$AcrName`" " +
            "--image `"$platTag`" " +
            "--platform `"$plat`" " +
            "--file `"$dockerfile`" " +
            $targetFlag + " " +
            "`"$context`""
        )
    }

    # If multiple platforms, stitch a manifest list so the bare :tag is multi-arch
    if ($platformList.Count -gt 1) {
        Write-Host "`n  Creating multi-arch manifest: $AcrLoginServer/$imageName`:$Tag" -ForegroundColor DarkGray
        $manifestRef = "$AcrLoginServer/$imageName`:$Tag"
        $sourceRefs  = $platformTags -join " "
        Invoke-Cmd "docker manifest create --amend `"$manifestRef`" $sourceRefs"
        Invoke-Cmd "docker manifest push `"$manifestRef`""
    }

    Write-Host "  Pushed: $AcrLoginServer/$imageName`:$Tag" -ForegroundColor Green
}

$buildBackend  = $Services -in @("backend",  "all")
$buildFrontend = $Services -in @("frontend", "all")

if ($UseAcrBuild) {
    if ($buildBackend) {
        Build-And-Push-Acr `
            -service     "backend" `
            -context     "$repoRoot\backend" `
            -dockerfile  "$repoRoot\backend\Dockerfile" `
            -imageName   "ai-app-backend" `
            -target      "production"
    }
    if ($buildFrontend) {
        Build-And-Push-Acr `
            -service     "frontend" `
            -context     "$repoRoot\frontend" `
            -dockerfile  "$repoRoot\frontend\Dockerfile" `
            -imageName   "ai-app-frontend" `
            -target      "production"
    }
} else {
    if ($buildBackend) {
        Build-And-Push `
            -service    "backend" `
            -context    "$repoRoot\backend" `
            -dockerfile "$repoRoot\backend\Dockerfile" `
            -image      $images.backend `
            -target     "production"
    }
    if ($buildFrontend) {
        Build-And-Push `
            -service    "frontend" `
            -context    "$repoRoot\frontend" `
            -dockerfile "$repoRoot\frontend\Dockerfile" `
            -image      $images.frontend `
            -target     "production"
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host "`n===================================================" -ForegroundColor Green
Write-Host " Build complete!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green

if ($buildBackend)  { Write-Host "  Backend:  $($images.backend)"  -ForegroundColor Green }
if ($buildFrontend) { Write-Host "  Frontend: $($images.frontend)" -ForegroundColor Green }

Write-Host ""
