param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install", "Start", "Stop", "Restart", "GetMycnf", "GetVariables", "Uninstall", "Echo")]
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

$ConfigFile | Write-Verbose

# directories are flatten.
. (Join-Path -Path $here -ChildPath "common-util.ps1")
. (Join-Path -Path $here -ChildPath "installer-server-function.ps1")

$configuration = Get-Configuration -ConfigFile $ConfigFile -ServerSide
$osConfig = $configuration.OsConfig


Get-ChildItem -Path (Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath "*.ps1") |
    Select-Object -ExpandProperty FullName |
    Where-Object {$_ -ne $myself} |
    ForEach-Object {
    . $_
}
try {
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
        "Start" {}
        "Stop" {}
        "Restart" {
            Update-MysqlStatus -StatusTo $Action
        }
        Default {
            $configuration | ConvertTo-Json -Depth 10
        }
    }
    
}
finally {
    if ($Global:MysqlExtraFile) {
        if (Test-Path -Path $Global:MysqlExtraFile) {
            Remove-Item -Path $Global:MysqlExtraFile -Force
        }
    }
}