$myself = $MyInvocation.MyCommand.Path
$ScriptDir = $myself | Split-Path -Parent
$CommonDir = $ScriptDir | Join-Path -ChildPath "common"
$ProjctRoot = $ScriptDir | Split-Path -Parent

$Global:ProjectRoot = $ProjctRoot
$Global:ScriptDir = $ScriptDir
$Global:CommonDir = $CommonDir
$Global:ProjectTmpDir = Join-Path -Path $ProjctRoot -ChildPath ".working"

if (-not (Test-Path $Global:ProjectTmpDir)) {
    New-Item -Path $Global:ProjectTmpDir -ItemType Directory | Out-Null
}