function Copy-BorgRepoFiles {
    param (
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][switch]$LogResult
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    $maxb = Get-MaxLocalDir -configuration $configuration
    $r = Copy-ChangedFiles -RemoteDirectory $configuration.BorgRepoPath -LocalDirectory $maxb
    if ($LogResult) {

    }
    $r
}