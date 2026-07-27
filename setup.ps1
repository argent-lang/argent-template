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
$ExpectedRevision = (Get-Content (Join-Path $TemplateDir ".argent-revision") -Raw).Trim()
$ArgentGitDir = Join-Path $ArgentDir ".git"

if (-not (Test-Path $ArgentGitDir -PathType Container)) {
    if (Test-Path $ArgentDir) {
        throw "$ArgentDir exists but is not an Argent Git checkout"
    }

    Write-Host "cloning Argent into $ArgentDir"
    Invoke-Native -Command "git" -Arguments @("clone", "https://github.com/argent-lang/argent", $ArgentDir)
    Invoke-Native -Command "git" -Arguments @("-C", $ArgentDir, "checkout", "--detach", $ExpectedRevision)
}

$CurrentRevision = (& git -C $ArgentDir rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "could not read the Argent revision from $ArgentDir"
}
if ($CurrentRevision -ne $ExpectedRevision) {
    throw @"
incompatible Argent checkout
expected: $ExpectedRevision
found:    $CurrentRevision
set ARGENT_TEMPLATE_ARGENT_DIR to select a compatible checkout
"@
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
