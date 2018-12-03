param (
    [Parameter(Mandatory = $true)][String]$RemoteDst,
    [Parameter(Mandatory = $false)][switch]$IncludeDownloads
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path -Path $here -ChildPath 'scripts' | Join-Path -ChildPath 'common' | Join-Path -ChildPath 'common-util.ps1')

$TmpDir = New-TemporaryDirectory

$exclude = '.vagrant', '.vscode', '.git', '.gitignore', 'downloads', "myconfigs"

if ($IncludeDownloads) {
    $exclude = $exclude | Where-Object {$_ -ne 'downloads'}
}

Get-ChildItem -Path $here | Where-Object {$_.Name -notin $exclude} | Copy-Item -Destination $TmpDir -Recurse
$cmd = "scp -r $($TmpDir.FullName) $RemoteDst"
$cmd | Write-Verbose
Invoke-Expression -Command $cmd
Remove-Item -Path $TmpDir -Recurse -Force

