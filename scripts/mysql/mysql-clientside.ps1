function Get-MysqlMaxDump {
    param (
        [Parameter(Mandatory = $false)]$configuration
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    if (-not (Test-Path -Path $configuration.LocalDir -PathType Container)) {
        New-Item -Path $configuration.LocalDir -ItemType 'Directory'
    }
    $bd = Join-Path -Path $configuration.LocalDir -ChildPath "dump"
    $maxb = Get-MaxBackup -Path $bd

    if (-not (Test-Path -Path $maxb -PathType Container)) {
        New-Item -Path $maxb -ItemType 'Directory'
    }
    $maxb
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
        } else {
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