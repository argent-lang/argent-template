$ErrorActionPreference = "Stop"

$InstallVscodeExt = $false
$UninstallVscodeExt = $false
foreach ($Argument in $args) {
    if ($Argument -eq "--vscode-ext") {
        $InstallVscodeExt = $true
    } elseif ($Argument -eq "--uninstall-vscode-ext") {
        $UninstallVscodeExt = $true
    } elseif ($Argument -eq "-h" -or $Argument -eq "--help") {
        Write-Host @"
Usage: ./setup [--vscode-ext | --uninstall-vscode-ext]

Options:
  --vscode-ext            Link Argent's VS Code extension into the user extension directory.
  --uninstall-vscode-ext  Remove links to the extension after VS Code has fully exited.
  -h, --help              Show this help.
"@
        exit 0
    } else {
        throw "unknown option: $Argument; try ./setup --help"
    }
}
if ($args.Count -gt 1) {
    throw "expected at most one option; try ./setup --help"
}

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

function Uninstall-VscodeExtension {
    $RunningCode = @(Get-Process -Name "Code" -ErrorAction SilentlyContinue)
    if ($RunningCode.Count -gt 0) {
        throw "VS Code is running; fully exit it before uninstalling the linked extension"
    }

    $Source = [System.IO.Path]::GetFullPath((Join-Path $ArgentDir "vscode\argent-syntax")).TrimEnd([char]"\")
    $ExtensionsDir = if ($env:VSCODE_EXTENSIONS_DIR) {
        $env:VSCODE_EXTENSIONS_DIR
    } else {
        Join-Path $env:USERPROFILE ".vscode\extensions"
    }
    if (-not (Test-Path $ExtensionsDir -PathType Container)) {
        Write-Host "Argent VS Code extension is not linked"
        return
    }

    $Links = @(
        Get-ChildItem -LiteralPath $ExtensionsDir -Force -Directory |
            Where-Object {
                if ($_.LinkType -ne "Junction" -and $_.LinkType -ne "SymbolicLink") {
                    return $false
                }

                $Target = [string]$_.Target
                if (-not [System.IO.Path]::IsPathRooted($Target)) {
                    $Target = Join-Path $ExtensionsDir $Target
                }
                $Target = [System.IO.Path]::GetFullPath($Target).TrimEnd([char]"\")
                [string]::Equals($Target, $Source, [System.StringComparison]::OrdinalIgnoreCase)
            }
    )
    if ($Links.Count -eq 0) {
        Write-Host "Argent VS Code extension is not linked"
        return
    }

    foreach ($Link in $Links) {
        $QuotedPath = "`"$($Link.FullName)`""
        Invoke-Native -Command "cmd.exe" -Arguments @("/d", "/c", "rmdir $QuotedPath")
        Write-Host "removed VS Code extension link: $($Link.FullName)"
    }
    Write-Host "Argent source checkout was left unchanged at $Source"
}

if ($UninstallVscodeExt) {
    Uninstall-VscodeExtension
    exit 0
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

function Install-VscodeExtension {
    $Source = Join-Path $ArgentDir "vscode\argent-syntax"
    $Manifest = Join-Path $Source "package.json"
    if (-not (Test-Path $Manifest -PathType Leaf)) {
        throw "Argent VS Code extension not found at $Source"
    }

    $Source = (Resolve-Path $Source).Path
    $Package = Get-Content $Manifest -Raw | ConvertFrom-Json
    if (-not $Package.publisher -or -not $Package.name -or -not $Package.version) {
        throw "could not read the Argent VS Code extension identity"
    }

    $ExtensionsDir = if ($env:VSCODE_EXTENSIONS_DIR) {
        $env:VSCODE_EXTENSIONS_DIR
    } else {
        Join-Path $env:USERPROFILE ".vscode\extensions"
    }
    $Destination = Join-Path $ExtensionsDir "$($Package.publisher).$($Package.name)-$($Package.version)"
    New-Item -ItemType Directory -Path $ExtensionsDir -Force | Out-Null

    $Existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if ($null -ne $Existing) {
        if ($Existing.LinkType -ne "Junction" -and $Existing.LinkType -ne "SymbolicLink") {
            throw "$Destination already exists and is not the expected link; remove it manually before installing the local Argent extension"
        }
        $ExistingTarget = [string]$Existing.Target
        if (-not [System.IO.Path]::IsPathRooted($ExistingTarget)) {
            $ExistingTarget = Join-Path $ExtensionsDir $ExistingTarget
        }
        $ExistingTarget = [System.IO.Path]::GetFullPath($ExistingTarget)
        if (-not [string]::Equals($ExistingTarget, $Source, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "$Destination already links to $ExistingTarget; refusing to replace it with $Source"
        }
        Write-Host "VS Code extension already linked: $Destination -> $Source"
    } else {
        New-Item -ItemType Junction -Path $Destination -Target $Source | Out-Null
        Write-Host "linked VS Code extension: $Destination -> $Source"
    }
    Write-Host "reload VS Code; the extension activates when an .ag file is opened"
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

if ($InstallVscodeExt) {
    Install-VscodeExtension
    Write-Host "Argent VS Code extension is ready"
    exit 0
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
