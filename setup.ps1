$ErrorActionPreference = "Stop"

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE"
    }
}

$TemplateDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceDir = Split-Path -Parent $TemplateDir
$ArgentDir = if ($env:ARGENT_TEMPLATE_ARGENT_DIR) {
    $env:ARGENT_TEMPLATE_ARGENT_DIR
} else {
    Join-Path $WorkspaceDir "argent"
}

if (Test-Path $ArgentDir) {
    $InsideWorkTree = (& git -C $ArgentDir rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -ne 0 -or $InsideWorkTree.Trim() -ne "true") {
        throw "$ArgentDir exists but is not an Argent Git checkout"
    }
} else {
    Write-Host "cloning Argent into $ArgentDir"
    Invoke-Native -Command "git" -Arguments @("clone", "--branch", "master", "https://github.com/argent-lang/argent", $ArgentDir)
}

function Get-GitText {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $Output = & git -C $ArgentDir @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
    return (($Output | Out-String).Trim())
}

function Test-GitRef {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Ref
    )

    & git -C $ArgentDir show-ref --verify --quiet $Ref
    return $LASTEXITCODE -eq 0
}

function Write-GitRelation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$Ref
    )

    $Revision = Get-GitText -Arguments @("rev-parse", $Ref)
    $Counts = (Get-GitText -Arguments @("rev-list", "--left-right", "--count", "HEAD...$Ref")) -split "\s+"
    Write-Host "${Label}: $Revision (HEAD ahead $($Counts[0]), behind $($Counts[1]))"
}

Write-Host "using Argent checkout at $ArgentDir"
Write-Host "HEAD: $(Get-GitText -Arguments @("rev-parse", "HEAD"))"
$Branch = (& git -C $ArgentDir symbolic-ref --quiet --short HEAD 2>$null)
if ($LASTEXITCODE -eq 0) {
    Write-Host "branch: $($Branch.Trim())"
} else {
    Write-Host "branch: detached"
}
$Upstream = (& git -C $ArgentDir rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>$null)
if ($LASTEXITCODE -eq 0) {
    $Upstream = $Upstream.Trim()
    Write-GitRelation -Label "upstream $Upstream" -Ref $Upstream
} else {
    Write-Host "upstream: none"
}
if (Test-GitRef -Ref "refs/heads/master") {
    Write-GitRelation -Label "local master" -Ref "refs/heads/master"
} else {
    Write-Host "local master: absent"
}
if (Test-GitRef -Ref "refs/remotes/origin/master") {
    Write-GitRelation -Label "recorded origin/master" -Ref "refs/remotes/origin/master"
    $OriginUrl = (& git -C $ArgentDir remote get-url origin 2>$null)
    if ($LASTEXITCODE -eq 0) {
        Write-Host "origin: $($OriginUrl.Trim())"
    } else {
        Write-Host "origin: not configured"
    }
    Write-Host "note: setup does not fetch or update an existing checkout"
} else {
    Write-Host "recorded origin/master: absent"
}
$WorkingTree = @(& git -C $ArgentDir status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw "could not inspect the Argent working tree"
}
if ($WorkingTree.Count -gt 0) {
    Write-Host "working tree: has local changes"
} else {
    Write-Host "working tree: clean"
}

Push-Location $TemplateDir
try {
    Write-Host "building the template"
    Invoke-Native -Command "cargo" -Arguments @("build")

    Write-Host "running the smoke demo"
    Invoke-Native -Command "cargo" -Arguments @("run", "--quiet", "--bin", "counter")

    Write-Host "Argent template is ready"
} finally {
    Pop-Location
}
