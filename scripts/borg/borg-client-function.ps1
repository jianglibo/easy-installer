function Copy-BorgRepoFiles {
    param (
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][switch]$OnlySum,
        [Parameter(Mandatory = $false)][switch]$Json
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    $maxb = Get-MaxLocalDir -configuration $configuration
    Copy-ChangedFiles -RemoteDirectory $configuration.BorgRepoPath -LocalDirectory $maxb -Json:$Json -OnlySum:$OnlySum
}