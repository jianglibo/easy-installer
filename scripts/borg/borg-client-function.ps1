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
    $dr = Copy-ChangedFiles -RemoteDirectory $configuration.BorgRepoPath -LocalDirectory $maxb -OnlySum:$OnlySum
    if ($Json) {
        $dr | ConvertTo-Json -Depth 10
    } else {
        $dr
    }
}