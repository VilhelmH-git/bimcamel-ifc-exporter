<#
.SYNOPSIS
    Cuts a release of BIMuttern (this BIMCamel fork) for BoomerHubb: build 2024-2027, stage the
    bundle, gate, publish on VilhelmH-git/BIMuttern-releases, point the catalog entry at it.

.DESCRIPTION
    BIMuttern is VilhelmH-git's fork of mrshoma99-rgb/bimcamel-ifc-exporter (MIT), renamed so it
    never collides with an upstream BIMCamel install: its own BIMuttern.dll, BIMuttern.bundle, plugin
    ids, ribbon tab and ProductCode. Colleagues get it through BoomerHubb, whose catalog entry
    "bimuttern" installs the zip's BIMuttern.bundle folder into %APPDATA%\Autodesk\ApplicationPlugins.
    The upstream .github/workflows/release.yml is the author's path and is not used here.

      1. Clean tree on main, pushed to the fork; gh, python, the release gate and the catalog
         script are here; no release with this version exists.
      2. BIMuttern.dll built once per Navisworks year (each must compile against its own year's
         API, restored from NuGet), with ContinuousIntegrationBuild so no local path is embedded.
      3. Staged as BIMuttern.bundle\<year>\{BIMuttern.dll, en-US\BIMuttern.xaml, Resources\*.png}
         plus PackageContents.xml stamped with the version through the XML DOM, LICENSE and
         README; validated; zipped as BIMuttern-v<version>-navisworks.zip.
      4. The release gate (claude-kit\tools\release-scan) over the zip: the releases repository
         is public.
      5. gh release create on VilhelmH-git/BIMuttern-releases, at the fork's commit.
      6. claude-kit\tools\catalog\set_entry.py --id bimuttern: every BoomerHubb offers the update.

.EXAMPLE
    .\packaging\new_release.ps1 -Version 0.12.0 -Notes .\whats-new.md
    .\packaging\new_release.ps1 -Version 0.12.0 -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [string]$Notes,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$releaseRepo = "VilhelmH-git/BIMuttern-releases"
$catalogId = "bimuttern"
$years = "2024", "2025", "2026", "2027"
$kit = if ($env:CLAUDE_KIT) { $env:CLAUDE_KIT } else { Join-Path (Split-Path $root -Parent) "claude-kit" }
$gate = Join-Path $kit "tools\release-scan\scan_package.py"
$setEntry = Join-Path $kit "tools\catalog\set_entry.py"

function Invoke-Native([string]$What, [scriptblock]$Body) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $global:LASTEXITCODE = 0
        & $Body 2>&1 | ForEach-Object { Write-Host "   $_" }
        if ($LASTEXITCODE -ne 0) { throw "$What failed (exit code $LASTEXITCODE)" }
    }
    finally { $ErrorActionPreference = $previous }
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must be <major>.<minor>.<patch>, got '$Version'." }
$tag = "v$Version"
Push-Location $root
try {
    # ── 1. Preconditions ────────────────────────────────────────────────────────────────
    Write-Host "1. Checking the tree and tools"
    foreach ($tool in "gh", "python", "dotnet", "git") {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool is not on PATH." }
    }
    foreach ($file in $gate, $setEntry) { if (-not (Test-Path $file)) { throw "Missing $file (set CLAUDE_KIT)." } }
    if (git status --porcelain) { throw "The tree is not clean: commit or stash first." }
    if ((git rev-parse --abbrev-ref HEAD) -ne "main") { throw "Release from main." }
    $head = git rev-parse HEAD
    # A dry run publishes nothing, so it may run before the fork and the releases repository exist.
    if (-not $DryRun) {
        Invoke-Native "git fetch fork" { git fetch fork main }
        if ($head -ne (git rev-parse fork/main)) { throw "main is not pushed to the fork (remote 'fork')." }
        # Windows PowerShell 5.1 turns a native command's stderr into a terminating error under
        # "Stop", and "release not found" arrives on stderr: probe with "Continue".
        $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        $null = & gh release view $tag --repo $releaseRepo --json url 2>&1
        $exists = $LASTEXITCODE -eq 0
        $ErrorActionPreference = $previous
        if ($exists) { throw "$releaseRepo already has $tag." }
    }

    # ── 2. Build per year ───────────────────────────────────────────────────────────────
    $out = Join-Path $root "out\release"
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }
    $staging = Join-Path $out "staging"
    $bundle = Join-Path $staging "BIMuttern.bundle"
    foreach ($year in $years) {
        Write-Host "2. Building for Navisworks $year"
        $bin = Join-Path $out "bin\$year"
        Invoke-Native "dotnet build $year" {
            dotnet build BIMCamel/BIMCamel.csproj -c Release --no-incremental -p:NavisworksYear=$year `
                -p:Version=$Version -p:ContinuousIntegrationBuild=true -p:Deterministic=true -o $bin
        }
        $yearDir = Join-Path $bundle $year
        New-Item -ItemType Directory -Force -Path (Join-Path $yearDir "en-US"), (Join-Path $yearDir "Resources") | Out-Null
        Copy-Item (Join-Path $bin "BIMuttern.dll") $yearDir
        Copy-Item "BIMCamel/BIMuttern.xaml" (Join-Path $yearDir "en-US")
        Copy-Item "BIMCamel/Resources/*.png" (Join-Path $yearDir "Resources")
        $fileVersion = (Get-Item (Join-Path $yearDir "BIMuttern.dll")).VersionInfo.FileVersion
        if ($fileVersion -ne "$Version.0") { throw "$year DLL carries version $fileVersion, expected $Version.0." }
    }

    # ── 3. Stage, validate, zip ─────────────────────────────────────────────────────────
    Write-Host "3. Staging the bundle"
    # Through the XML DOM, never a string edit: a broken declaration makes Navisworks ignore the bundle.
    [xml]$manifest = Get-Content "dist/BIMuttern.bundle/PackageContents.xml" -Raw
    $manifest.ApplicationPackage.Version = "$Version.0"
    $manifestPath = Join-Path $bundle "PackageContents.xml"
    $manifest.Save($manifestPath)
    [xml]$check = Get-Content $manifestPath -Raw
    if ($check.ApplicationPackage.Version -ne "$Version.0") { throw "Staged PackageContents.xml failed validation." }
    foreach ($component in $check.ApplicationPackage.Components) {
        $module = Join-Path $bundle ($component.ComponentEntry.ModuleName -replace '^\.\\', '')
        if (-not (Test-Path $module)) { throw "PackageContents names $module, which is not staged." }
    }
    Copy-Item "LICENSE" $staging
    Copy-Item "dist/README.md" $staging
    $zip = Join-Path $out "BIMuttern-$tag-navisworks.zip"
    Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $zip
    Write-Host ("   {0} ({1:N0} bytes)" -f (Split-Path $zip -Leaf), (Get-Item $zip).Length)

    # ── 4. Release gate ─────────────────────────────────────────────────────────────────
    Write-Host "4. Release gate"
    Invoke-Native "release gate" { python $gate $zip }

    if ($DryRun) { Write-Host "Dry run: stopping before anything is published. Zip: $zip"; return }

    # ── 5. Publish ──────────────────────────────────────────────────────────────────────
    Write-Host "5. Publishing $tag on $releaseRepo"
    $notesFile = Join-Path $out "notes.md"
    $body = if ($Notes) { Get-Content $Notes -Raw } else { "" }
    $body += "`n`nBuilt from https://github.com/VilhelmH-git/bimcamel-ifc-exporter/commit/$head, a fork of " +
             "[BIMCamel IFC Exporter](https://github.com/mrshoma99-rgb/bimcamel-ifc-exporter) (MIT licence).`n`n" +
             "SHA-256: ``$((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant())``"
    Set-Content -Path $notesFile -Value $body -Encoding utf8
    Invoke-Native "gh release create" {
        gh release create $tag $zip --repo $releaseRepo --title "BIMuttern $Version" --notes-file $notesFile --latest
    }

    # ── 6. Catalog ──────────────────────────────────────────────────────────────────────
    Write-Host "6. Pointing catalog entry '$catalogId' at $tag"
    Invoke-Native "set_entry.py" { python $setEntry --id $catalogId --repo $releaseRepo --tag $tag }
    Write-Host "Done: $tag published and in the catalog."
}
finally { Pop-Location }
