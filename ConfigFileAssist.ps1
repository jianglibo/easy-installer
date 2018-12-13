param (
    [ValidateSet("borg", "mysql")]
    [string]$AppName,
    [ValidateSet("python", "powershell")]
    [string]$ServerLang,
    [string]$ConfigDir,
    [string]$HostNameOrIp
)

if (-not (Test-Path -Path $ConfigDir -PathType Container)) {
    "Dir $ConfigDir doesn't exists!" | Out-Host
    return
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

. ($here | Join-Path -ChildPath 'scripts' | Join-Path -ChildPath 'global-variables.ps1')

. $Global:CommonUtil
. $Global:ClientUtil

$appfolder = $Global:ScriptDir | Join-Path -ChildPath $AppName

$ToFileName = $ConfigDir | Join-Path -ChildPath $HostNameOrIp
if (-not (Test-Path -Path $ToFileName -PathType Container)) {
    New-Item -Path $ToFileName -ItemType Directory | Out-Null
}
$ToFileName = $ToFileName | Join-Path -ChildPath "${AppName}-config.json"

$cmd = "Copy-DemoConfigFile -MyDir $appfolder -ToFileName $ToFileName -ServerLang $serverlang -HostName $HostNameOrIp"

$cmd | Write-Verbose

Invoke-Expression -Command $cmd


