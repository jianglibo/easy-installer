<#
.SYNOPSIS
RemoteDumpFileWithHashValue contains file hash and length.

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
    $maxb = Get-MaxLocalDir -configuration $configuration -Next

    $RemoteDumpFileWithHashValue | Write-Verbose

    $fn = Split-UniversalPath -Path $RemoteDumpFileWithHashValue.Path -Leaf
    $tf = Join-UniversalPath -Path $maxb -ChildPath $fn

    $RemoteDumpFileWithHashValue | Add-Member @{LocalPath=$tf}
    $r = Copy-FilesFromServer -RemotePathes $RemoteDumpFileWithHashValue.Path -LocalDirectory $maxb

    $fh = Get-FileHash -Path $RemoteDumpFileWithHashValue.LocalPath

    if ($fh.Hash -ne $RemoteDumpFileWithHashValue.Hash) {
        throw "$($fh.Hash) Hash value doesn't match the server side file's."
    }
    $tdump = Join-Path -Path $maxb -ChildPath "dump.sql"
    Move-Item -Path $RemoteDumpFileWithHashValue.LocalPath -Destination $tdump
    $RemoteDumpFileWithHashValue.LocalPath = $tdump

    @{files=@($RemoteDumpFileWithHashValue);Count=1;Length=$RemoteDumpFileWithHashValue.Length}
    
}

function Copy-MysqlLogFiles {
    param (
        [parameter(Mandatory = $true, Position = 0)][array]$RemoteLogFilesWithHashValue,
        [Parameter(Mandatory = $false)]$configuration
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    $maxb = Get-MaxLocalDir -configuration $configuration

    $RemoteLogFilesWithHashValue | Write-Verbose

    # filter out already exist files.
    $RemoteLogFilesWithHashValue = $RemoteLogFilesWithHashValue | Select-Object -SkipLast 1 |
        ForEach-Object {
        $fn = Split-UniversalPath -Path $_.Path -Leaf
        $tf = Join-UniversalPath $maxb $fn
        $_ | Add-Member @{LocalPath=$tf} -PassThru
    }

    $idxfile = Join-Path -Path $maxb -ChildPath 'logbin.index'

    $RemoteLogFilesWithHashValue | ForEach-Object {$_.LocalPath} | Out-File -Encoding ascii -FilePath $idxfile


    $NeedDownload = $RemoteLogFilesWithHashValue |
        Where-Object {
        $exists = Test-Path -Path $_.LocalPath
        if ($exists) {
            $localfileHash = Get-FileHash -Path $_.LocalPath
            $b = $localfileHash.Hash -ne $_.Hash
            $b
        }
        else {
            $true
        }
    }
        
    $rpathes = $NeedDownload | ForEach-Object {$_.Path} | Sort-Object

    if (-not $rpathes) {
        return
    }

    $r = Copy-FilesFromServer -RemotePathes $rpathes -LocalDirectory $maxb
    # verify all downloaded file.
    [array]$files = $NeedDownload | ForEach-Object {
        $fh = Get-FileHash -Path $_.LocalPath
        if ($fh.Hash -ne $_.Hash) {
            throw "file $($fh.Path) with length $($fh.Length)  with hash $($fh.Hash) Hash value doesn't match the server side file's."
        }
        $_
    }
    $mo = $files | Measure-Object -Property Length -Sum
    @{Length=$mo.Sum;files=$files;Count=$mo.Count}
}