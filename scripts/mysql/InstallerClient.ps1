param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install", "Start", "Stop", "Restart", "GetDemoConfigFile", "DownloadPackages","SendPackages", "Remove")]
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

$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

$Global:ProjectRoot = $ScriptDir | Split-Path -Parent

".\SshInvoker.ps1", ".\common-util.ps1", ".\clientside-util.ps1" | ForEach-Object {
    . "${ScriptDir}\common\$_"
}

$isInstall = $Action -eq "Install"

if ($isInstall -and (-not $ConfigFile)) {
    Write-ParameterWarning -wstring "If action is Install then ConfigFile parameter is required."
    return
}

if ($isInstall -and (-not $Version)) {
    Write-ParameterWarning -wstring "If action is Install then Version parameter is required."
    return
}

if ($Action -eq "GetDemoConfigFile") {
    Copy-DemoConfigFile -MyDir $here -ToFileName "mysql-config.json"
}
else {
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
        "Remove" {
            if ($PSCmdlet.ShouldContinue("Are you sure?", "")) {
                "removed."
            }
            else {
                "canceled."
            }
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