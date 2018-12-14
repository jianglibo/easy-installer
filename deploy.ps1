param (
    [Parameter(Mandatory = $false)][String]$RemoteUser="Administrator",
    [Parameter(Mandatory = $false)][String]$RemotePath="d:\\easy-installers",
    [Parameter(Mandatory = $false)][String]$RemoteHost = "172.19.253.244",
    [Parameter(Mandatory = $false)][switch]$IncludeDownloads,
    [switch]$NotCleanUp
)

$RemoteDst = "${RemoteUser}@${RemoteHost}:$RemotePath"
$RemoteDst | Write-Verbose
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$zipname = "easy-installer.zip"

$t = New-TemporaryFile
Remove-Item $t
$TmpDir = New-Item -Path $t -ItemType Directory

$eiDir = New-Item -Path ($TmpDir.FullName | Join-Path -ChildPath 'easy-installer') -ItemType Directory

try {
    $exclude = '.vagrant', '.vscode', '.git', '.gitignore', 'downloads', "myconfigs", ".working", "sshdebug", "*.pyc"

    if ($IncludeDownloads) {
        $exclude = $exclude | Where-Object {$_ -ne 'downloads'}
    }

    Get-ChildItem -Path $here | Where-Object {$_.Name -notin $exclude} | Copy-Item -Destination $eiDir -Recurse -Exclude '*.pyc'

    $finalzip = "${TmpDir}\$zipname"

    $cmd = "Compress-Archive -Path ${eiDir}\* -DestinationPath $finalzip"

    $cmd | Write-Verbose

    Invoke-Expression -Command $cmd

    $cmd = "scp $finalzip $RemoteDst"
    $cmd | Write-Verbose
    Invoke-Expression -Command $cmd

    $RemoteZip = "$RemotePath\$zipname"

    $fn = $zipname -split '\.' | Select-Object -First 1

    $RemoteUnzipDir = "$RemotePath\$fn"

    $cmd = "ssh ${RemoteUser}@$RemoteHost `"powershell -Command {Expand-Archive -Path $RemoteZip  -DestinationPath $RemoteUnzipDir -Force}`""

    $cmd | Write-Verbose

    Invoke-Expression -Command $cmd
}
finally {
    if (-not $NotCleanUp) {
        Remove-Item -Recurse -Force $TmpDir
    }
}

