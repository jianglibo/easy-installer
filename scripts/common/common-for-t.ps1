$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent
$CommonDir = $ScriptDir | Join-Path -ChildPath "common"

$Global:ProjectRoot = $ScriptDir | Split-Path -Parent
$Global:ScriptDir = $ScriptDir
$Global:CommonDir = $CommonDir
$Global:ProjectTmpDir = Join-Path -Path $Global:ProjectRoot -ChildPath ".working"

if (-not (Test-Path $Global:ProjectTmpDir)) {
    New-Item -Path $Global:ProjectTmpDir -ItemType Directory | Out-Null
}

function Copy-TestPsScriptToServer {
    Param(
        [Parameter(Mandatory = $true, Position = 0)][string]$HerePath,
        [parameter(Mandatory = $false)]
        [ValidateSet("python", "powershell")]$Lang="powershell",
        [Parameter(Mandatory = $false, Position = 1)][string]$ConfigFile
    )
    if (-not $ConfigFile) {
        $ConfigFile = $HerePath | Join-Path -ChildPath "demo-config.${Lang}.1.json"
    }
    # $sflf = $HerePath | Join-Path -ChildPath "serversidefilelist.txt"
    $configuration = Get-Configuration -ConfigFile $ConfigFile
    # Copy-PsScriptToServer -ConfigFile $ConfigFile -ServerSideFileListFile $sflf | Out-Null
    Copy-PsScriptToServer -ConfigFile $ConfigFile | Out-Null
    # @{ConfigFile=$ConfigFile;configuration=$configuration;ServerSideFileListFile=$sflf}
    @{ConfigFile = $ConfigFile; configuration = $configuration}
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
        [Parameter(Mandatory = $true, Position = 0)][string]$HerePath,
        [switch]$ServerSide
    )
    $ConfigFile = $HerePath | Join-Path -ChildPath "demo-config.1.json"
    Get-Configuration -ConfigFile $ConfigFile -ServerSide:$ServerSide
}