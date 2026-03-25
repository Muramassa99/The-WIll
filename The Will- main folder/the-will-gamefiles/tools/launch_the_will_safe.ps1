param(
	[switch]$UseGui,
	[switch]$Headless,
	[switch]$Editor,
	[string]$DisplayDriver = "",
	[string]$RenderingDriver = "",
	[string]$RenderingMethod = "",
	[int]$QuitAfterSeconds = 0
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = (Resolve-Path (Join-Path $scriptDir "..")).Path
$workspaceDir = (Resolve-Path (Join-Path $projectDir "..\\..")).Path
$godotDir = Join-Path $workspaceDir "Godot_v4.6.1"
$logDir = Join-Path $workspaceDir "godot_runs"

if ($UseGui -and $Headless) {
	throw "Choose either -UseGui or -Headless, not both."
}
if ($Editor -and $Headless) {
	throw "Editor mode cannot run with -Headless."
}

$godotExeName = if ($UseGui -or $Editor) {
	"Godot_v4.6.1-stable_win64.exe"
} else {
	"Godot_v4.6.1-stable_win64_console.exe"
}
$godotExePath = Join-Path $godotDir $godotExeName

if (-not (Test-Path $godotExePath)) {
	throw "Godot executable not found at $godotExePath"
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = Join-Path $logDir "the_will_$timestamp.log"

$arguments = @("--log-file", $logPath, "--path", $projectDir)
if ($Headless) {
	$arguments = @("--headless") + $arguments
}
if ($Editor) {
	$arguments = @("--editor") + $arguments
}
if ($DisplayDriver -ne "") {
	$arguments = @("--display-driver", $DisplayDriver) + $arguments
}
if ($RenderingDriver -ne "") {
	$arguments = @("--rendering-driver", $RenderingDriver) + $arguments
}
if ($RenderingMethod -ne "") {
	$arguments = @("--rendering-method", $RenderingMethod) + $arguments
}
if ($QuitAfterSeconds -gt 0) {
	$arguments += @("--quit-after", $QuitAfterSeconds.ToString())
}

Write-Host "Project:" $projectDir
Write-Host "Executable:" $godotExePath
Write-Host "Log file:" $logPath

& $godotExePath @arguments
$exitCode = $LASTEXITCODE

Write-Host "Godot exited with code $exitCode"
exit $exitCode
