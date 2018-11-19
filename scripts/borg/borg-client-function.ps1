function Copy-BorgRepoFiles {
    param (
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][switch]$LogResult,
        [Parameter(Mandatory = $false)][switch]$OnlySum,
        [Parameter(Mandatory = $false)][switch]$Json
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    $maxb = Get-MaxLocalDir -configuration $configuration
    $r = Copy-ChangedFiles -RemoteDirectory $configuration.BorgRepoPath -LocalDirectory $maxb -Json:$Json -OnlySum:$OnlySum
    if ($LogResult) {
        if ($Json) {
            $r | Out-File -FilePath (Get-LogFile -group 'borgdownload')
        } else {
            $r | ConvertTo-Json -Depth 10 | Out-File -FilePath (Get-LogFile -group 'borgdownload')
        }
    }
    $r
}