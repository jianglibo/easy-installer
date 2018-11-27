param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install",
        "Start",
        "Stop", 
        "Restart", 
        "Status", 
        "GetMycnf", 
        "EnableLogbin",
        "GetVariables", 
        "Dump", 
        "FlushLogs", 
        "MysqlExtraFile", 
        "Uninstall", 
        "Echo", 
        "DownloadPublicKey", 
        "RunSQL", 
        "UpdateMysqlPassword")]
    [string]$Action,
    [parameter(Mandatory = $false)][switch]$NotCleanUp,
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
. (Join-Path -Path $here -ChildPath "mysql-server-function.ps1")

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
            Get-MysqlVariables $hints
            break
        }
        "Uninstall" {
            Uninstall-Mysql
            break
        }
        {$PSItem -in "Start", "Stop", "Status", "Restart"} {
            Update-MysqlStatus -StatusTo $Action
            break
        }
        "DownloadPublicKey" {
            Get-OpenSSLPublicKey
            break
        }
        "UpdateMysqlPassword" {
            if ($hints) {
                Update-MysqlPassword -EncryptedNewPwd $hints[0] -EncryptedOldPwd $hints[1]
            }
            break
        }
        "RunSQL" {
            $sql = $hints | Where-Object {$PSItem -notmatch '^-.*'}
            $sql = "`"$sql`""
            $opts = $hints | Where-Object {$PSItem -match '^-.*'}
            $line = "Invoke-MysqlSQLCommand -sql $sql $opts"
            $line | Write-Verbose
            Invoke-Expression -Command $line
        }
        "Dump" {
            Invoke-MysqlDump -UsePlainPwd "$hints"
            break
        }
        "FlushLogs" {
            Invoke-MysqlFlushLogs -UsePlainPwd "$hints"
            break
        }
        "MysqlExtraFile" {
            New-MysqlExtraFile -UsePlainPwd "$hints"
            break
        }
        "EnableLogbin" {
            Get-MycnfFile | Enable-Logbin -LogbinBasename "$hints"
            break
        }
        Default {
            $configuration | ConvertTo-Json -Depth 10
        }
    }
}
finally {
    if ($Global:MysqlExtraFile) {
        if (-not $NotCleanUp) {
            if (Test-Path -Path $Global:MysqlExtraFile) {
                Remove-Item -Path $Global:MysqlExtraFile -Force
            }
        }
        $Global:MysqlExtraFile = $null
    }
    $PSDefaultParameterValues['*:Verbose'] = $false
}