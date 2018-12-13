param (
    [Parameter(Mandatory = $true)]
    [ValidatePattern(".+@.+:.+")]
    [ValidateSet("Administrator@172.19.253.244:d:\\easy-installers")]
    [String]$RemoteDst,
    [Parameter(Mandatory = $false)][switch]$IncludeDownloads,
    [switch]$NotCleanUp
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path


$t = New-TemporaryFile
Remove-Item $t
$TmpDir = New-Item -Path $t -ItemType Directory

$eiDir = New-Item -Path ($TmpDir.FullName | Join-Path -ChildPath 'easy-installer') -ItemType Directory

try {
    $exclude = '.vagrant', '.vscode', '.git', '.gitignore', 'downloads', "myconfigs", ".working", "sshdebug"

    if ($IncludeDownloads) {
        $exclude = $exclude | Where-Object {$_ -ne 'downloads'}
    }

    Get-ChildItem -Path $here | Where-Object {$_.Name -notin $exclude} | Copy-Item -Destination $eiDir -Recurse

    $finalzip = "${TmpDir}\easy-installer.zip"

    $cmd = "Compress-Archive -Path ${eiDir}\* -DestinationPath $finalzip"

    $cmd | Write-Verbose

    Invoke-Expression -Command $cmd

    $cmd = "scp $finalzip $RemoteDst"
    $cmd | Write-Verbose
    Invoke-Expression -Command $cmd
}
finally {
    if (-not $NotCleanUp) {
        Remove-Item -Recurse -Force $TmpDir
    }
}

