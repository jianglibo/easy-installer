function Copy-TestPsScriptToServer {
    Param(
        [Parameter(Mandatory = $true, Position = 0)][string]$HerePath,
        [Parameter(Mandatory = $false, Position = 1)][string]$ConfigFile
    )
    if (-not $ConfigFile) {
        $ConfigFile = $HerePath | Join-Path -ChildPath "demo-config.1.json"
    }
    $sflf = $HerePath | Join-Path -ChildPath "serversidefilelist.txt"
    $configuration = Get-Configuration -ConfigFile $ConfigFile
    Copy-PsScriptToServer -configuration $configuration -ConfigFile $ConfigFile -ServerSideFileListFile $sflf | Out-Null
    @{ConfigFile=$ConfigFile;configuration=$configuration;ServerSideFileListFile=$sflf}
}

function Get-ConfigFileInTestDriver {
    Param(
        [Parameter(Mandatory = $true, Position = 0)][string]$HerePath,
        [Parameter(Mandatory = $false, Position = 1)][hashtable]$OneLevelHashTable
    )
    $repofile = Join-Path $TestDrive "config.json"
    $repofile | Write-Verbose
    $configuration = Get-DemoConfiguration -HerePath $HerePath
    
    Get-ChangedHashtable -customob $configuration -OneLevelHashTable $OneLevelHashTable | Out-Null
    
    $configuration | ConvertTo-Json -Depth 10 | Out-File -FilePath $repofile
    $repofile
}

function Get-DemoConfiguration {
    Param(
        [Parameter(Mandatory = $true, Position = 0)][string]$HerePath
    )
    $ConfigFile = $HerePath | Join-Path -ChildPath "demo-config.1.json"
    Get-Configuration -ConfigFile $ConfigFile
}