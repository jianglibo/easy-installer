param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install","GetMycnf","GetVariables","Uninstall", "Echo")]
    [string]$Action,
    [parameter(Mandatory = $false,
        ValueFromRemainingArguments = $true)]
    [String[]]
    $hints
)

$vb = $PSBoundParameters.ContainsKey('Verbose')
if ($vb) {
    $PSDefaultParameterValues['*:Verbose'] = $true
}

"hints is: $($hints -join ' ')" | Write-Verbose

$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent

$ConfigFile = $here | Join-Path -ChildPath "config.json"

. (Join-Path -Path $here -ChildPath "common-util.ps1")

$configuration = Get-Configuration -ConfigFile $ConfigFile -ServerSide
$osConfig = $configuration.OsConfig


Get-ChildItem -Path (Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath "*.ps1") |
    Select-Object -ExpandProperty FullName |
    Where-Object {$_ -ne $myself} |
    ForEach-Object {
    . $_
}

switch ($Action) {
    "Echo" {
        $hints -join ' '
        break
    }
    "Install" {
        Install-Mysql -Version "$hints"
        break
    }
    "GetMycnf" {
        Get-MycnfFile
        break
    }
    "GetVariables" {
        Get-MysqlVariables "$hints"
        break
    }
    "Uninstall" {
        Uninstall-Mysql
        break
    }
    Default {
        $configuration | ConvertTo-Json -Depth 10
    }
}