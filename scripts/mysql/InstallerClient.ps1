param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install", "GetDemoConfigFile", "DownloadPackages", "Remove")]
    [string]$Action,
    [parameter(Mandatory = $false)]
    [string]$ConfigFile,
    [parameter(Mandatory = $false)]
    [ValidateSet("55", "56", "57", "80")]
    [string]$Version
)

process { 
    $vb = $PSBoundParameters.ContainsKey('Verbose')
    if ($vb) {
        $PSDefaultParameterValues['*:Verbose'] = $true
    }

    $myself = $MyInvocation.MyCommand.Path
    $here = $myself | Split-Path -Parent
    $ScriptDir = $here | Split-Path -Parent

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
        Copy-DemoConfigFile -MyDir $here -ToFileName "mysql-demo-config.json"
    }
    else {
        $configuration = Get-Configuration -ConfigFile $ConfigFile
        if (-not $configuration) {
            return
        }
        switch ($Action) {
            "DownloadPackages" {
                Get-SoftwarePackages -configuration $configuration
                break
            }
            "Remove" {
                if ($PSCmdlet.ShouldContinue("Are you sure?", "")) {
                    "removed."
                } else {
                    "canceled."
                }
            }
            Default {
                $configuration = Get-Configuration -MyDir $here -ConfigFile $ConfigFile
                $configuration | ConvertTo-Json
            }
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