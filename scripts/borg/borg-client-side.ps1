param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install",
        "DownloadPackages",
        "CopyDemoConfigFile",
        "SendPackages", 
        "Uninstall", 
        "DownloadPublicKey")]
    [string]$Action,
    [parameter(Mandatory = $false)]
    [string]$ConfigFile,
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

. (Join-Path -Path $here -ChildPath 'borg-client-function.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'ssh-invoker.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'common-util.ps1')
. (Join-Path -Path $CommonDir -ChildPath 'clientside-util.ps1')

if ($Action -eq "CopyDemoConfigFile") {
    Copy-DemoConfigFile -MyDir $here -ToFileName "borg-config.json"
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
                Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action
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
        Default {
            Invoke-ServerRunningPs1 -ConfigFile -$ConfigFile -action $Action
        }
    }
}