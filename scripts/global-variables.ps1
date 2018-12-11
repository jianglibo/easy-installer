$myself = $MyInvocation.MyCommand.Path
$ScriptDir = $myself | Split-Path -Parent
$CommonDir = $ScriptDir | Join-Path -ChildPath "common"
$ProjctRoot = $ScriptDir | Split-Path -Parent

$Global:ProjectRoot = $ProjctRoot
$Global:ScriptDir = $ScriptDir
$Global:CommonDir = $CommonDir
$Global:ProjectTmpDir = Join-Path -Path $ProjctRoot -ChildPath ".working"
$Global:CommonUtil = Join-Path -Path $Global:CommonDir -ChildPath 'common-util.ps1'
$Global:ClientUtil = Join-Path -Path $Global:CommonDir -ChildPath 'clientside-util.ps1'
$Global:SshInvoker = Join-Path -Path $Global:CommonDir -ChildPath 'ssh-invoker.ps1'

if (-not (Test-Path $Global:ProjectTmpDir)) {
    New-Item -Path $Global:ProjectTmpDir -ItemType Directory | Out-Null
}