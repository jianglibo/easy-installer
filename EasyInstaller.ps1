param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Mysql")]
    [string]$AppName,
    [parameter(Mandatory=$true, Position = 1)]
    [ValidateSet("Install", "DemoConfigFile")]
    [string]$action,
    [parameter(Mandatory=$false, Position = 2)]
    [string]$ConfigFile
)

$vb = $PSBoundParameters.ContainsKey('Verbose')
if ($vb) {
    $PSDefaultParameterValues['*:Verbose'] = $true
}
$proot = Split-Path -Parent $MyInvocation.MyCommand.Path

$appfolder = ($AppName -csplit '(?<!^)(?=[A-Z])',5 |ForEach-Object {([string]$_).ToLower()}) -join '-'

. "${proot}\scripts\common\ssh-invoker.ps1"

# $hints | Out-String | Write-Verbose

# $psDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# . "${psDir}\internal\deploy-config.ps1"
# . "${psDir}\internal\ssh-invoker.ps1"
# . "${psDir}\internal\deploy-util.ps1"
# $ConfigFile = "${psDir}\deploy.json"
# $dconfig = Get-DeployConfig -ConfigFile $ConfigFile

switch ($action) {
    "DemoConfigFile" {
        $democfg = $proot | Join-Path -ChildPath "scripts" | Join-Path -ChildPath $appfolder | Join-Path -ChildPath "README.md" -Resolve
        $demofolder = $PWD | Join-Path -ChildPath "demo-configs"
        if (-not (Test-Path -Path $demofolder)) {
            New-Item -Path $demofolder -ItemType "directory" | Out-Null
        }
        $tofile = $demofolder | Join-Path -ChildPath "${AppName}.json"
        Copy-Item -Path $democfg -Destination $tofile
        break
    }
    Default {
    }
}