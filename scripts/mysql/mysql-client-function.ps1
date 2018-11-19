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
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][switch]$LogResult
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }

    $starttime = Get-Date
    $maxb = Get-MaxLocalDir -configuration $configuration -Next

    $RemoteDumpFileWithHashValue | Write-Verbose

    $fn = Split-UniversalPath -Path $RemoteDumpFileWithHashValue.Path -Leaf
    $tf = Join-UniversalPath $maxb $fn
    $RemoteDumpFileWithHashValue | Add-Member @{LocalFile=$tf}
    $r = Copy-FilesFromServer -RemotePathes $RemoteDumpFileWithHashValue.Path -LocalDirectory $maxb

    $fh = Get-FileHash -Path $RemoteDumpFileWithHashValue.LocalFile
    if ($fh.Hash -ne $RemoteDumpFileWithHashValue.Hash) {
        throw "$($fh.Hash) Hash value doesn't match the server side file's."
    }
    $tdump = Join-Path -Path $maxb -ChildPath "dump.sql"
    Move-Item -Path $RemoteDumpFileWithHashValue.LocalFile -Destination $tdump
    $RemoteDumpFileWithHashValue.Path = $tdump

    $timespan = (Get-Date) - $starttime

    $RemoteDumpFileWithHashValue | Add-Member @{timespan=$timespan}

    if ($LogResult) {
        $RemoteDumpFileWithHashValue | ConvertTo-Json -Depth 10 | Out-File -FilePath (Get-LogFile -group 'mysqldump')
    }
    $RemoteDumpFileWithHashValue

}

function Copy-MysqlLogFiles {
    param (
        [parameter(Mandatory = $true, Position = 0)][array]$RemoteLogFilesWithHashValue,
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][switch]$LogResult
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    $starttime = Get-Date
    $maxb = Get-MaxLocalDir -configuration $configuration

    $RemoteLogFilesWithHashValue | Write-Verbose

    # filter out already exist files.
    $RemoteLogFilesWithHashValue = $RemoteLogFilesWithHashValue |
        ForEach-Object {
        $fn = Split-UniversalPath -Path $_.Path -Leaf
        $tf = Join-UniversalPath $maxb $fn
        $_ | Add-Member @{LocalFile=$tf} -PassThru
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
    $files = $RemoteLogFilesWithHashValue | ForEach-Object {
        $fh = Get-FileHash -Path $_.LocalFile
        if ($fh.Hash -ne $_.Hash) {
            throw "$($fh.Hash) Hash value doesn't match the server side file's."
        }
        $_
    }
    $mo = $files | Measure-Object -Property Length -Sum
    $timespan = (Get-Date) - $starttime
    $r = @{Length=$mo.Sum;files=$files;Count=$mo.Count;timespan=$timespan}
    if ($LogResult) {
        $r | ConvertTo-Json -Depth 10 | Out-File -FilePath (Get-LogFile -group 'mysqlflush')
    }
    $r
}