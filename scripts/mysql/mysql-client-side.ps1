param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install",
        "Start",
        "Stop", 
        "Restart",
        "GetDemoConfigFile",
        "Status", 
        "DownloadPackages",
        "SendPackages", 
        "Uninstall", 
        "MysqlFlushLogs",
        "MysqlDump",
        "MysqlBackupDump",
        "DownloadPublicKey")]
    [string]$Action,
    [parameter(Mandatory = $false)]
    [string]$ConfigFile,
    [parameter(Mandatory = $false)]
    [ValidateSet("55", "56", "57", "80")]
    [string]$Version,
    [switch]$CopyScripts
)

<#
    Put configuration values in Global scope is a choice.
    1. openssl executable(client and server)
    2. private key file.
    3. configuration it's self.
#>

$vb = $PSBoundParameters.ContainsKey('Verbose')
if ($vb) {
    $PSDefaultParameterValues['*:Verbose'] = $true
}
else {
    $PSDefaultParameterValues['*:Verbose'] = $false
}

$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent
$CommonDir = $ScriptDir | Join-Path -ChildPath "common"

$Global:ProjectRoot = $ScriptDir | Split-Path -Parent

. (Join-Path -Path $here -ChildPath 'mysql-client-function.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'ssh-invoker.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'common-util.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'clientside-util.ps1')

$isInstall = $Action -eq "Install"


if ($isInstall -and (-not $Version)) {
    Write-ParameterWarning -wstring "If action is Install then Version parameter is required."
    return
}

if ($Action -eq "GetDemoConfigFile") {
    Copy-DemoConfigFile -MyDir $here -ToFileName "mysql-config.json"
}
else {
    if (-not $ConfigFile) {
        Write-ParameterWarning -wstring "This action need ConfigFile parameter, If you don't know what ConfigFile is, run Action 'GetDemoConfigFile' first."
        return
    }

    $configuration = Get-Configuration -ConfigFile $ConfigFile
    if (-not $configuration) {
        return
    }
    if ($CopyScripts) {
        Copy-PsScriptToServer -ConfigFile $ConfigFile -ServerSideFileListFile ($here | Join-Path -ChildPath "serversidefilelist.txt")
    }
    switch ($Action) {
        "DownloadPackages" {
            $configuration.DownloadPackages()
            break
        }
        "SendPackages" {
            Send-SoftwarePackages
            break
        }
        "Uninstall" {
            if ($PSCmdlet.ShouldContinue("Are you sure?", "")) {
                Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action $Version
            }
            else {
                "canceled."
            }
            break
        }
        "DownloadPublicKey" {
            $r = Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action | Receive-LinesFromServer
            $sshInvoker = Get-SshInvoker
            $f = Get-PublicKeyFile -NotResolve
            $sshInvoker.ScpFrom($r, $f, $false)
            break
        }
        "MysqlDump" {
            $r = Invoke-ServerRunningPs1 -ConfigFile $ConfigFile -action MysqlDump
            $ht = $r | Receive-LinesFromServer | ConvertFrom-ListFormatOutput
            $ht | Write-Verbose
            $df = Copy-MysqlDumpFile -RemoteDumpFileWithHashValue $ht
            break
        }
        "MysqlFlushLogs" {
            $r = Invoke-ServerRunningPs1 -ConfigFile $ConfigFile -action MysqlFlushLogs
            $ht = $r | Receive-LinesFromServer | ConvertFrom-ListFormatOutput
            Copy-MysqlLogFiles -RemoteLogFilesWithHashValue $ht
            break
        }
        "MysqlBackupDump" {
            $d = Get-MysqlMaxDump
            Backup-LocalDirectory -Path $d -keepOrigin
            Resize-BackupFiles -BasePath $d -Pattern $configuration.DumpPrunePattern
            break
        }
        Default {
            Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action $Version
            # $configuration = Get-Configuration -ConfigFile $ConfigFile
            # $configuration | ConvertTo-Json -Depth 10
        }
    }
}

# DynamicParam {
#     if (($action -eq "Install")) {
#         $attributes = New-Object -Type `
#             System.Management.Automation.ParameterAttribute
#         $attributes.ParameterSetName = "PSet1"
#         $attributes.Mandatory = $false
#         $attributeCollection = New-Object `
#             -Type System.Collections.ObjectModel.Collection[System.Attribute]
#         $attributeCollection.Add($attributes)

#         $dynConfigFile = New-Object -Type `
#             System.Management.Automation.RuntimeDefinedParameter("ConfigFile", [string],
#             $attributeCollection)

#         $paramDictionary = New-Object `
#             -Type System.Management.Automation.RuntimeDefinedParameterDictionary
#         $paramDictionary.Add("ConfigFile", $dynConfigFile)
#         return $paramDictionary
#     }
# }