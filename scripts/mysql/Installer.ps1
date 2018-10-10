param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install", "GetDemoConfigFile", "DownloadPackages")]
    [string]$Action,
    [parameter(Mandatory = $false)]
    [string]$ConfigFile
)

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

process { 
    $vb = $PSBoundParameters.ContainsKey('Verbose')
    if ($vb) {
        $PSDefaultParameterValues['*:Verbose'] = $true
    }
    $invalid = ($Action -eq "Install") -and (-not $ConfigFile)

    if ($invalid) {
        Write-ParameterWarning -wstring "If action is Install then ConfigFile is required."
        return
    }

    $myself = $MyInvocation.MyCommand.Path
    $here = $myself | Split-Path -Parent
    $ScriptsDir = $here | Split-Path -Parent

    . "${ScriptsDir}\common\SshInvoker.ps1"
    . "${ScriptsDir}\common\clientside-util.ps1"
    . "${myself}.ps1"

    if ($Action -eq "GetDemoConfigFile") {
        Copy-DemoConfigFile -MyDir $here -ToFileName "mysql-demo-config.json"
    }
    else {
        $configuration = Get-Configuration -MyDir $here -ConfigFile $ConfigFile
        if (-not $configuration) {
            return
        }
        switch ($Action) {
            "DownloadPackages" {
                Download-SoftwarePackages -configuration $configuration
                break
            }
            Default {
                $configuration = Get-Configuration -MyDir $here -ConfigFile $ConfigFile
                $configuration | ConvertTo-Json
            }
        }
    }
}