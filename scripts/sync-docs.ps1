<#
sync-docs.ps1
PowerShell helper to synchronize three folders from a source path into the repo:
- Datos
- Documentación
- media

Usage examples:

PS> .\scripts\sync-docs.ps1 -SourcePath 'D:\AVA\Cartografia-Forestal-AVA_source' -Push

This script will:
- create/checkout branch `update/docs-sync` from origin/main
- mirror the three folders using robocopy
- stage only those folders, commit with a clear message
- optionally push the branch to origin

It will explicitly restore `README.md` and the `Evaluación/` folder from HEAD
if they were changed by accident before committing.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    [string]$BranchName = 'update/docs-sync',

    [string]$Remote = 'origin',

    [switch]$Push
)

function Abort([string]$msg){ Write-Error $msg; exit 1 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Abort 'git is not available in PATH.' }
if (-not (Get-Command robocopy -ErrorAction SilentlyContinue)) { Abort 'robocopy is required (built-in on Windows).' }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if (-not $repoRoot) { Abort 'Not inside a git repository. Run this from the repo root.' }

if (-not (Test-Path -Path $SourcePath)) { Abort "Source path '$SourcePath' does not exist." }

Write-Host "Repo root: $repoRoot"
Set-Location $repoRoot

Write-Host "Fetching $Remote..."
git fetch $Remote --prune

# Create or reset the branch from remote/main
if (git show-ref --verify --quiet "refs/heads/$BranchName") {
    Write-Host "Branch $BranchName exists locally — resetting to $Remote/main"
    git checkout $BranchName
    git reset --hard "$Remote/main"
} else {
    Write-Host "Creating branch $BranchName from $Remote/main"
    git checkout -b $BranchName "$Remote/main"
}

function MirrorFolder($src, $dst) {
    if (-not (Test-Path -Path $src)) { Write-Warning "Source folder '$src' does not exist — creating empty folder at destination."; New-Item -ItemType Directory -Force -Path $dst | Out-Null }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    $cmd = "robocopy `"$src`" `"$dst`" /MIR /Z /NFL /NDL /NJH /NJS"
    Write-Host "Running: $cmd"
    iex $cmd | Out-Null
}

# Mirror the three target folders
$pairs = @( 
    @{s = Join-Path $SourcePath 'Datos'; d = Join-Path $repoRoot 'Datos'},
    @{s = Join-Path $SourcePath 'Documentación'; d = Join-Path $repoRoot 'Documentación'},
    @{s = Join-Path $SourcePath 'media'; d = Join-Path $repoRoot 'media'}
)

foreach ($p in $pairs) { MirrorFolder $p.s $p.d }

Write-Host "Inspecting git status..."
git status --porcelain

# Restore README and Evaluación if changed accidentally
git restore --source=HEAD -- README.md 2>$null || Write-Host 'README.md unchanged or not present in HEAD'
git restore --source=HEAD -- "Evaluación/" 2>$null || Write-Host 'Evaluación/ unchanged or not present in HEAD'

Write-Host "Staging only target folders..."
git add --all Datos "Documentación" media

$staged = git diff --staged --name-only
if (-not $staged) { Write-Host "No changes staged for Datos/Documentación/media. Exiting."; exit 0 }

Write-Host "Staged changes:"
git diff --staged --name-status

$msg = "Actualizar Datos, Documentación y media desde $SourcePath (sin modificar README ni Evaluación)"
git commit -m $msg

if ($Push) {
    Write-Host "Pushing branch $BranchName to $Remote..."
    git push -u $Remote $BranchName
    Write-Host "Push complete. Open a PR from $BranchName to main if you want review before merging."
} else {
    Write-Host "Commit created on branch $BranchName. To push, run: git push -u $Remote $BranchName"
}
