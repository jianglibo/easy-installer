param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install","GetMycnf","GetVariables","Uninstall", "Echo")]
    [string]$Action,
    [parameter(Mandatory = $true, Position = 1)]
    [string]$ConfigFile,
    [parameter(Mandatory = $false, Position = 2)]
    [string]$PrivateKeyFile,
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

. (Join-Path -Path $here -ChildPath "common-util.ps1")

$configuration = Get-Configuration -ConfigFile $ConfigFile -ServerSide -PrivateKeyFile $PrivateKeyFile
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
        Install-Mysql -configuration $configuration -Version "$hints"
        break
    }
    "GetMycnf" {
        Get-MycnfFile -configuration $configuration
        break
    }
    "GetVariables" {
        Get-MysqlVariables -configuration $configuration "$hints"
        break
    }
    "Uninstall" {
        Uninstall-Mysql -configuration $configuration
        break
    }
    Default {
        $configuration | ConvertTo-Json -Depth 10
    }
}