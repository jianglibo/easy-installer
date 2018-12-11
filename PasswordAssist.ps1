param (
    [Parameter(Mandatory = $false)][string]$ConfigFile,
    [Parameter(Mandatory = $false)][string]$ServerPublicKeyFile,
    [ValidateSet("EncryptPassword", "SetMysqlPassword", "DownloadPublicKey", "CopyDemoConfigFile")]
    [string]$Action
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

. ($here | Join-Path -ChildPath 'scripts' | Join-Path -ChildPath 'global-variables.ps1')

. $Global:CommonUtil
. $Global:ClientUtil

"importing $($Global:ClientUtil)" | Write-Verbose
"importing $($Global:CommonUtil)" | Write-Verbose

if ($Action -eq "CopyDemoConfigFile") {
    $appname = ""
    while ($appname -notin 'borg', 'mysql') {
        $appname = Read-Host -Prompt "Please enter: borg|mysql"
    }
    $serverlang = ""
    while ($serverlang -notin 'python', 'powershell') {
        $serverlang = Read-Host -Prompt "Please enter server side language: python|powershell"
    }

    $appfolder = $Global:ScriptDir | Join-Path -ChildPath $appname
    Copy-DemoConfigFile -MyDir $appfolder -ToFileName "${appname}-config.json" -ServerLang $serverlang
    return
}

while ((-not $ConfigFile) -or (-not (Test-Path -Path $ConfigFile))) {
    $ConfigFile = Read-Host -Prompt "Please enter the path of configuration file:"
}

$configuration = Get-Configuration -ConfigFile $ConfigFile
if (-not $configuration) {
    return
}
Copy-PsScriptToServer -ConfigFile $ConfigFile

switch ($Action) {
    "EncryptPassword" { 
        if (-not $ServerPublicKeyFile) {
            $ServerPublicKeyFile = Get-ServerPublicKeyFile
        }
        Protect-PasswordByOpenSSLPublicKey -ServerPublicKeyFile $ServerPublicKeyFile
        break
    }
    "SetMysqlPassword" { 
        if (-not $ServerPublicKeyFile) {
            $ServerPublicKeyFile = Get-ServerPublicKeyFile
        }
        $s = Protect-PasswordByOpenSSLPublicKey -ServerPublicKeyFile $ServerPublicKeyFile
        $Global:configuration.MysqlPassword = $s
        $Global:configuration.PSObject.Properties.Remove('OsConfig')
        $Global:configuration | ConvertTo-Json -Depth 10 | Out-File $ConfigFile
        break
    }
    "DownloadPublicKey" {
        $r = Invoke-ServerRunningPs1 -action $Action
        $r | Write-Verbose
        $r = $r | Receive-LinesFromServer
        $sshInvoker = Get-SshInvoker
        $f = Get-ServerPublicKeyFile -NotResolve
        $sshInvoker.ScpFrom($r, $f, $false)
        $sshInvoker.invoke("rm $r")
        break
    }
    Default {
        "Unimplement action."
    }
}