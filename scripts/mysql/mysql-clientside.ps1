function Get-MysqlMaxDump {
    param (
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][switch]$Next

    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    if (-not (Test-Path -Path $configuration.LocalDir -PathType Container)) {
        New-Item -Path $configuration.LocalDir -ItemType 'Directory' | Out-Null
    }
    $bd = Join-Path -Path $configuration.LocalDir -ChildPath "dumps" | Join-Path -ChildPath "dump"
    if ($Next) {
        $maxb = Get-NextBackup -Path $bd
    } else {
        $maxb = Get-MaxBackup -Path $bd
    }

    if (-not (Test-Path -Path $maxb -PathType Container)) {
        New-Item -Path $maxb -ItemType 'Directory' | Out-Null
    }
    $maxb
}
<#
.SYNOPSIS
Short description

.DESCRIPTION
Dumpping mysql will create a new backup directory.

.PARAMETER RemoteDumpFileWithHashValue
Parameter description

.PARAMETER configuration
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Copy-MysqlDumpFile {
    param (
        [parameter(Mandatory = $true, Position = 0)]$RemoteDumpFileWithHashValue,
        [Parameter(Mandatory = $false)]$configuration
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    $maxb = Get-MysqlMaxDump -configuration $configuration -Next

    $fn = Split-UniversalPath -Path $RemoteDumpFileWithHashValue.Path -Leaf
    $tf = Join-UniversalPath $maxb $fn
    $RemoteDumpFileWithHashValue.LocalFile = $tf
    $r = Copy-FilesFromServer -RemotePathes $RemoteDumpFileWithHashValue.Path -LocalDirectory $maxb

    $fh = Get-FileHash -Path $RemoteDumpFileWithHashValue.LocalFile
    if ($fh.Hash -ne $RemoteDumpFileWithHashValue.Hash) {
        throw "$($fh.Hash) Hash value doesn't match the server side file's."
    }
    $tdump = Join-Path -Path $maxb -ChildPath "dump.sql"
    Move-Item -Path $RemoteDumpFileWithHashValue.LocalFile -Destination $tdump
    $tdump
}

function Copy-MysqlLogFiles {
    param (
        [parameter(Mandatory = $true, Position = 0)][array]$RemoteLogFilesWithHashValue,
        [Parameter(Mandatory = $false)]$configuration
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }

    $maxb = Get-MysqlMaxDump -configuration $configuration

    # filter out already exist files.
    $RemoteLogFilesWithHashValue = $RemoteLogFilesWithHashValue |
        ForEach-Object {
        $fn = Split-UniversalPath -Path $_.Path -Leaf
        $tf = Join-UniversalPath $maxb $fn
        $_.LocalFile = $tf
        $_
    }

    $idxfile = Join-Path -Path $maxb -ChildPath 'logbin.index'

    $RemoteLogFilesWithHashValue | ForEach-Object {$_.LocalFile} | Out-File -Encoding ascii -FilePath $idxfile
        
    $rpathes = $RemoteLogFilesWithHashValue |
        Where-Object {
        $exists = Test-Path -Path $_.LocalFile
        if ($exists) {
            $localfileHash = Get-FileHash -Path $_.LocalFile
            $b = $localfileHash.Hash -ne $_.Hash
            $b
        }
        else {
            $true
        }
    } | ForEach-Object {$_.Path} | Sort-Object

    if (-not $rpathes) {
        return
    }

    $r = Copy-FilesFromServer -RemotePathes $rpathes -LocalDirectory $maxb
    # verify all downloaded file.
    $RemoteLogFilesWithHashValue | ForEach-Object {
        $fh = Get-FileHash -Path $_.LocalFile
        if ($fh.Hash -ne $_.Hash) {
            throw "$($fh.Hash) Hash value doesn't match the server side file's."
        }
    }
    $r
}