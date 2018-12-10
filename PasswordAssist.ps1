param (
    [Parameter(Mandatory = $true, Position = 0)][string]$ConfigFile,
    [Parameter(Mandatory = $false)][string]$PublicKeyFile,
    [Parameter(Mandatory = $false)]
    [ValidateSet("EncryptPassword", "SetMysqlPassword", "DownloadPublicKey")]
    [string]$Action="EncryptPassword"
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

. ($here | Join-Path -ChildPath 'scripts' | Join-Path -ChildPath 'global-variables.ps1')

. $Global:CommonUtil
. $Global:ClientUtil

"importing $($Global:ClientUtil)" | Write-Verbose
"importing $($Global:CommonUtil)" | Write-Verbose

$configuration = Get-Configuration -ConfigFile $ConfigFile
if (-not $configuration) {
    return
}
Copy-PsScriptToServer -ConfigFile $ConfigFile

switch ($Action) {
    "EncryptPassword" { 
        Protect-PasswordByOpenSSLPublicKey -PublicKeyFile $PublicKeyFile
        break
     }
    "SetMysqlPassword" { 
        $s = Protect-PasswordByOpenSSLPublicKey -PublicKeyFile $PublicKeyFile
        $Global:configuration.MysqlPassword = $s
        $Global:configuration.PSObject.Properties.Remove('OsConfig')
        $Global:configuration | ConvertTo-Json -Depth 10 | Out-File $ConfigFile
        break
     }
     "DownloadPublicKey" {
        $r = Invoke-ServerRunningPs1 -action $Action
        $r = $r | Receive-LinesFromServer
        $sshInvoker = Get-SshInvoker
        $f = Get-PublicKeyFile -NotResolve
        $sshInvoker.ScpFrom($r, $f, $false)
        $sshInvoker.invoke("rm $r")
        break
    }
    Default {
        "Unimplement action."
    }
}