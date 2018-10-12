function Copy-TestPsScriptToServer {
    Param(
        [Parameter(Mandatory = $true, Position = 0)][string]$HerePath
    )
    $ConfigFile = $HerePath | Join-Path -ChildPath "demo-config.1.json"
    $sflf = $HerePath | Join-Path -ChildPath "serversidefilelist.txt"
    $configuration = Get-Configuration -ConfigFile $ConfigFile
    Copy-PsScriptToServer -configuration $configuration -ConfigFile $ConfigFile -ServerSideFileListFile $sflf | Out-Null
    @{ConfigFile=$ConfigFile;configuration=$configuration;ServerSideFileListFile=$sflf}
}

function Get-DuplicatedConfigFile {
    Param(
        [Parameter(Mandatory = $true, Position = 0)][string]$OriginConfigFile
    )
    $repofile = Join-Path $TestDrive "config.json"
    $repofile | Write-Verbose
    Copy-Item -Path $OriginConfigFile -Destination $repofile
    $repofile
}