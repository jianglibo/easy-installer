param (
    [Parameter(Mandatory = $true)][ValidateSet("home", "office")][string]$InvokeFromWhere,
    [Parameter(Mandatory = $false)][string]$ServerPublicKeyFile,
    [ValidateSet("EncryptPassword", "SetMysqlPassword", "DownloadPublicKey")]
    [string]$Action
)

$Cxmap = @{home="";office="E:\pyvenvs\3.6.7\Scripts\"}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$dist = $here | Join-Path -ChildPath "dist"

$zip = $here | Join-Path -ChildPath 'dir_watcher.zip'

$pyscriptdir = $here | Join-Path -ChildPath "scripts" | Join-Path -ChildPath "python" 
$pyscript = $pyscriptdir | Join-Path -ChildPath "dir_watcher.py"
$cxfreeze = $Cxmap.$InvokeFromWhere

$democonfig = $pyscriptdir | Join-Path -ChildPath "dir_watcher.json"

$cmd = "{0}python.exe {1}cxfreeze {2}" -f $cxfreeze, $cxfreeze, $pyscript

"start invoking command: $cmd" | Write-Verbose
Invoke-Expression -Command $cmd

Copy-Item -Path $democonfig -Destination $dist

Compress-Archive -Path $dist -DestinationPath $zip -Update