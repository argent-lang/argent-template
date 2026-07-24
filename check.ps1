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

Push-Location $TemplateDir
try {
    Invoke-Native -Command "cargo" -Arguments @("fmt", "--check")
    Invoke-Native -Command "cargo" -Arguments @("check", "--all-targets")
    Invoke-Native -Command "cargo" -Arguments @("test", "--all-targets")
    Invoke-Native -Command "cargo" -Arguments @("clippy", "--all-targets", "--", "-D", "warnings")
    Invoke-Native -Command "cargo" -Arguments @("run", "--quiet", "--bin", "counter")
    Invoke-Native -Command "git" -Arguments @("diff", "--check")
} finally {
    Pop-Location
}
