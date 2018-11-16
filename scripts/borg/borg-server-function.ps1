function Install-Borg {
    param (
        [parameter(Mandatory = $false)][string]$Version
    )
    if (-not $Global:configuration.BorgBin) {
        throw "configuration file error: BorgBin property does'nt exists."
    }
    if (Test-Path -Path $Global:configuration.BorgBin -PathType Leaf) {
        "AlreadyInstalled"
    }
    else {
        $OsConfig = $Global:configuration.OsConfig
        Get-SoftwarePackages -TargetDir $OsConfig.ServerSide.PackageDir -Softwares $OsConfig.Softwares
        $pk = Get-SoftwarePackagePath
        Copy-Item -Path $pk -Destination $Global:configuration.BorgBin
        $chmod = "chmod 755 {0}" -f $Global:configuration.BorgBin
        Invoke-Expression -Command $chmod
        "Install Success." | Send-LinesToClient
    }
}

function UnInstall-Borg {
    param (
        [parameter(Mandatory = $false)][string]$Version
    )
    if (-not $Global:configuration.BorgBin) {
        throw "configuration file error: BorgBin property does'nt exists."
    }
    if (Test-Path -Path $Global:configuration.BorgBin -PathType Leaf) {
        Remove-Item -Path $Global:configuration.BorgBin
        "Uninstall successly." | Send-LinesToClient
    }
    else {
        "borg hadn't be installed." | Send-LinesToClient
    }
}

function Initialize-BorgRepo {
    param (
        [parameter(Mandatory = $false)][string]$RepoPath,
        [parameter(Mandatory = $false)]
        [ValidateSet("repokey", "keyfile", "repokey-blake2", "keyfile-blake2", "none")]
        [string]$encryption = 'none'
    )
    if (-not $RepoPath) {
        $RepoPath = $Global:configuration.BorgRepoPath
    }

    if (-not (Test-Path $RepoPath -PathType Container)) {
        New-Item -Path $RepoPath -ItemType Directory
    }
    $cmd = "{0} init --encryption={1} {2}" -f $Global:configuration.BorgBin, $encryption, $RepoPath
    $cmd | Write-Verbose
    Invoke-Expression -Command $cmd
    if ($LASTEXITCODE -ne 0) {
        "FAIL" | Send-LinesToClient
    } else {
        "SUCCESS" | Send-LinesToClient
    }
}

function New-BorgArchive {
    param (
        [parameter(Mandatory = $false)][string]$RepoPath,
        [parameter(Mandatory = $false)][string]$ArchiveName
    )
    if (-not $RepoPath) {
        $RepoPath = $Global:configuration.BorgRepoPath
    }
    if (-not $ArchiveName) {
        $cmd = "{0} list --json {1}" -f $Global:configuration.BorgBin, $RepoPath
        $listResult = Invoke-Expression -Command $cmd | ConvertFrom-Json
        $ArchiveName = 1 + ($listResult.archives | Select-Object -Last 1).name
        "got new archive name: $ArchiveName" | Write-Verbose
    }
    $createcmd = $Global:configuration.BorgCreate -f $Global:configuration.BorgBin, $RepoPath, $ArchiveName
    Invoke-Expression -Command $createcmd | Send-LinesToClient
}

function Invoke-BorgPrune {
    param (
        [parameter(Mandatory = $false)][string]$RepoPath
    )
    if (-not $RepoPath) {
        $RepoPath = $Global:configuration.BorgRepoPath
    }
    $createcmd = $Global:configuration.BorgPrune -f $Global:configuration.BorgBin, $RepoPath
    Invoke-Expression -Command $createcmd | Send-LinesToClient
}