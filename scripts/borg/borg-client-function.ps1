# place holder.
function Get-BorgMaxRepo {
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
    $bd = Join-Path -Path $configuration.LocalDir -ChildPath "repos" | Join-Path -ChildPath "repo"
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


function Copy-BorgRepoFiles {
    param (
        [parameter(Mandatory = $true, Position = 0)][array]$RemoteRepoFilesWithHashValue,
        [Parameter(Mandatory = $false)]$configuration
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }

    $maxb = Get-BorgMaxRepo -configuration $configuration

    # filter out already exist files.
    $RemoteRepoFilesWithHashValue = $RemoteRepoFilesWithHashValue |
        ForEach-Object {
        $fn = Split-UniversalPath -Path $_.Path -Leaf
        $tf = Join-UniversalPath $maxb $fn
        $_.LocalFile = $tf
        $_
    }
    $rpathes = $RemoteRepoFilesWithHashValue |
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
    $RemoteRepoFilesWithHashValue | ForEach-Object {
        $fh = Get-FileHash -Path $_.LocalFile
        if ($fh.Hash -ne $_.Hash) {
            throw "$($fh.Hash) Hash value doesn't match the server side file's."
        }
    }
    $r
}