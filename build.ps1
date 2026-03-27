Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
if ($PSVersionTable.PSVersion.Major -ge 7) {
  $PSNativeCommandUseErrorActionPreference = $true
}

function New-Directory {
  param([Parameter(Mandatory)] [string]$Path)
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Resolve-AbsolutePath {
  param([Parameter(Mandatory)] [string]$Path)

  return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Set-DefaultEnvironmentValue {
  param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$Value
  )

  if (-not [System.Environment]::GetEnvironmentVariable($Name)) {
    Set-Item -Path "Env:$Name" -Value $Value
  }
}

function Invoke-ExternalCommand {
  param(
    [Parameter(Mandatory)] [string]$FilePath,
    [string[]]$ArgumentList = @()
  )

  Write-Host "> $FilePath $($ArgumentList -join ' ')"
  & $FilePath @ArgumentList
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($ArgumentList -join ' ')"
  }
}

function Invoke-ExternalCommandWithRetry {
  param(
    [Parameter(Mandatory)] [string]$FilePath,
    [string[]]$ArgumentList = @(),
    [int]$MaxAttempts = 4,
    [int]$InitialDelaySeconds = 5,
    [string]$CleanupPath
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      Invoke-ExternalCommand -FilePath $FilePath -ArgumentList $ArgumentList
      return
    } catch {
      if ($attempt -ge $MaxAttempts) {
        throw
      }

      if ($CleanupPath -and (Test-Path -LiteralPath $CleanupPath)) {
        Remove-Item -LiteralPath $CleanupPath -Recurse -Force
      }

      $delaySeconds = $InitialDelaySeconds * $attempt
      Write-Warning "Attempt $attempt of $MaxAttempts failed for '$FilePath'. Retrying in $delaySeconds seconds..."
      Start-Sleep -Seconds $delaySeconds
    }
  }
}

function Repair-GitSymlinks {
  param([Parameter(Mandatory)] [string]$ModuleDir)

  $entries = & git -C $ModuleDir ls-files -s
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect git symlinks in $ModuleDir"
  }

  foreach ($entry in $entries) {
    if ($entry -notmatch '^120000 ') {
      continue
    }

    $parts = $entry -split "`t", 2
    if ($parts.Count -ne 2) {
      continue
    }

    $linkPath = Join-Path $ModuleDir $parts[1]
    if (-not (Test-Path -LiteralPath $linkPath)) {
      continue
    }

    $item = Get-Item -LiteralPath $linkPath -Force
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
      continue
    }

    $relativeTarget = (Get-Content -LiteralPath $linkPath -Raw).Trim()
    if (-not $relativeTarget) {
      continue
    }

    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $item.DirectoryName $relativeTarget))
    Write-Host "Repairing git symlink placeholder: $linkPath -> $sourcePath"
    Copy-Item -LiteralPath $sourcePath -Destination $linkPath -Force
  }
}

function Patch-DunePythonCommonMacros {
  param([Parameter(Mandatory)] [string]$InstallPrefix)

  $macrosPath = Join-Path $InstallPrefix "share\dune\cmake\modules\DunePythonCommonMacros.cmake"
  if (-not (Test-Path -LiteralPath $macrosPath)) {
    throw "Could not find DunePythonCommonMacros.cmake at $macrosPath"
  }

  $contents = Get-Content -LiteralPath $macrosPath -Raw
  $contents = $contents -replace '(?m)^(\s*)find_package\(Python', '$1#find_package(Python'
  $contents = $contents -replace '(?m)^(\s*)dune_python_find_package\(', '$1#dune_python_find_package('
  Set-Content -LiteralPath $macrosPath -Value $contents -NoNewline
}

$requiredEnvVars = @(
  "DUNE_COPASI_VERSION",
  "INSTALL_PREFIX",
  "OS"
)

foreach ($name in $requiredEnvVars) {
  if (-not (Get-Item -Path "Env:$name" -ErrorAction SilentlyContinue)) {
    throw "$name is not set"
  }
}

$buildTag = if ($env:BUILD_TAG) { $env:BUILD_TAG } else { "" }
$repoRoot = (Get-Location).Path
$installPrefix = Resolve-AbsolutePath $env:INSTALL_PREFIX
$workRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } elseif ($env:TEMP) { $env:TEMP } else { Join-Path $repoRoot ".tmp" }
$workDir = Resolve-AbsolutePath (Join-Path $workRoot "sme-deps-dune-copasi")
$duneCopasiDir = Join-Path $workDir "dune-copasi"
$duneDependenciesDir = Join-Path $workDir "dune-dependencies"

Set-DefaultEnvironmentValue -Name "CMAKE_POLICY_VERSION_MINIMUM" -Value "3.5"
Set-DefaultEnvironmentValue -Name "BUILD_SHARED_LIBS" -Value "OFF"
Set-DefaultEnvironmentValue -Name "BUILD_TESTING" -Value "ON"
Set-DefaultEnvironmentValue -Name "CMAKE_BUILD_TYPE" -Value "Release"
Set-DefaultEnvironmentValue -Name "CMAKE_C_COMPILER" -Value "cl"
Set-DefaultEnvironmentValue -Name "CMAKE_CXX_COMPILER" -Value "cl"
Set-DefaultEnvironmentValue -Name "CMAKE_C_COMPILER_LAUNCHER" -Value "ccache"
Set-DefaultEnvironmentValue -Name "CMAKE_CXX_COMPILER_LAUNCHER" -Value "ccache"
Set-DefaultEnvironmentValue -Name "CMAKE_MSVC_RUNTIME_LIBRARY" -Value 'MultiThreaded$<$<CONFIG:Debug>:Debug>'
Set-DefaultEnvironmentValue -Name "CMAKE_CXX_FLAGS" -Value "/permissive- /Zc:__cplusplus /Zc:preprocessor /bigobj /EHsc /external:anglebrackets"
Set-DefaultEnvironmentValue -Name "CMAKE_DISABLE_FIND_PACKAGE_MPI" -Value "ON"
Set-DefaultEnvironmentValue -Name "CMAKE_GENERATOR" -Value "Ninja"
Set-DefaultEnvironmentValue -Name "DUNE_ENABLE_PYTHONBINDINGS" -Value "OFF"
Set-DefaultEnvironmentValue -Name "DUNE_PDELAB_ENABLE_TRACING" -Value "OFF"
Set-DefaultEnvironmentValue -Name "DUNE_COPASI_DISABLE_FETCH_PACKAGE_ExprTk" -Value "ON"
Set-DefaultEnvironmentValue -Name "CMAKE_DISABLE_FIND_PACKAGE_parafields" -Value "ON"
Set-DefaultEnvironmentValue -Name "DUNE_COPASI_DISABLE_FETCH_PACKAGE_parafields" -Value "ON"
Set-DefaultEnvironmentValue -Name "DUNE_COPASI_GRID_DIMENSIONS" -Value "2;3"

Write-Host "DUNE_COPASI_VERSION = $env:DUNE_COPASI_VERSION"
Write-Host "INSTALL_PREFIX = $env:INSTALL_PREFIX"
Write-Host "BUILD_TAG = $buildTag"
Write-Host "OS = $env:OS"
Write-Host "TARGET_TRIPLE = $env:TARGET_TRIPLE"
Write-Host "HOST_TRIPLE = $env:HOST_TRIPLE"
Write-Host "CMAKE_BUILD_TYPE = $env:CMAKE_BUILD_TYPE"
Write-Host "CMAKE_GENERATOR = $env:CMAKE_GENERATOR"
Write-Host "CMAKE_C_COMPILER = $env:CMAKE_C_COMPILER"
Write-Host "CMAKE_CXX_COMPILER = $env:CMAKE_CXX_COMPILER"
Write-Host "CMAKE_C_COMPILER_LAUNCHER = $env:CMAKE_C_COMPILER_LAUNCHER"
Write-Host "CMAKE_CXX_COMPILER_LAUNCHER = $env:CMAKE_CXX_COMPILER_LAUNCHER"
Write-Host "CMAKE_MSVC_RUNTIME_LIBRARY = $env:CMAKE_MSVC_RUNTIME_LIBRARY"
Write-Host "CMAKE_CXX_FLAGS = $env:CMAKE_CXX_FLAGS"
Write-Host "BUILD_SHARED_LIBS = $env:BUILD_SHARED_LIBS"
Write-Host "BUILD_TESTING = $env:BUILD_TESTING"
Write-Host "DUNE_COPASI_GRID_DIMENSIONS = $env:DUNE_COPASI_GRID_DIMENSIONS"
Write-Host "PATH = $env:PATH"
Write-Host "git = $((Get-Command git -ErrorAction Stop).Source)"
Invoke-ExternalCommand git @("--version")
Write-Host "git-lfs = $((Get-Command git-lfs -ErrorAction Stop).Source)"
Invoke-ExternalCommand git @("lfs", "version")
Write-Host "cl = $((Get-Command cl -ErrorAction Stop).Source)"
Write-Host "ninja = $((Get-Command ninja -ErrorAction Stop).Source)"
Invoke-ExternalCommand ninja @("--version")
Write-Host "cmake = $((Get-Command cmake -ErrorAction Stop).Source)"
Invoke-ExternalCommand cmake @("--version")

if (Test-Path -LiteralPath $workDir) {
  Remove-Item -LiteralPath $workDir -Recurse -Force
}

New-Directory $workDir
New-Directory $installPrefix

Invoke-ExternalCommandWithRetry -FilePath git -CleanupPath $duneCopasiDir -ArgumentList @(
  "clone",
  "--branch",
  $env:DUNE_COPASI_VERSION,
  "--depth",
  "1",
  "--single-branch",
  "https://gitlab.dune-project.org/copasi/dune-copasi.git",
  $duneCopasiDir
)

Repair-GitSymlinks $duneCopasiDir
Invoke-ExternalCommand git @("-C", $duneCopasiDir, "rev-parse", "HEAD")
Invoke-ExternalCommand git @("-C", $duneCopasiDir, "lfs", "pull")

$buildScript = Join-Path $duneCopasiDir ".ci\build.ps1"
if (-not (Test-Path -LiteralPath $buildScript)) {
  throw "Could not find dune-copasi build script at $buildScript"
}

& $buildScript -RepoRoot $duneCopasiDir -WorkDir $duneDependenciesDir -InstallPrefix $installPrefix -CleanWorkDir

Patch-DunePythonCommonMacros -InstallPrefix $installPrefix

if (Get-Command ccache -ErrorAction SilentlyContinue) {
  Invoke-ExternalCommand ccache @("--show-stats")
}

$artefactsDir = Join-Path $repoRoot "artefacts"
New-Directory $artefactsDir
Push-Location $artefactsDir
try {
  $tmpTar = "tmp.tar"
  $archiveName = "sme_deps_$($env:OS)$buildTag.tgz"

  if (Test-Path -LiteralPath $tmpTar) {
    Remove-Item -LiteralPath $tmpTar -Force
  }
  if (Test-Path -LiteralPath $archiveName) {
    Remove-Item -LiteralPath $archiveName -Force
  }

  Invoke-ExternalCommand 7z @("a", $tmpTar, $env:INSTALL_PREFIX)
  Invoke-ExternalCommand 7z @("a", $archiveName, $tmpTar)
  Remove-Item -LiteralPath $tmpTar -Force
} finally {
  Pop-Location
}
