param (
    [Parameter(Mandatory = $true, Position = 0)][string]$PublicKeyFile,
    [Parameter(Mandatory = $true, Position = 1)][string]$ConfigFile,
    [Parameter(Mandatory = $false)]
    [ValidateSet("EncryptPassword", "SetMysqlPassword")]
    [string]$Action="EncryptPassword"
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

. ($here | Join-Path -ChildPath "scripts" | Join-Path -ChildPath "common" | Join-Path -ChildPath "common-util.ps1")

switch ($Action) {
    "EncryptPassword" { 
        Get-Configuration -ConfigFile $ConfigFile
        Protect-PasswordByOpenSSLPublicKey -PublicKeyFile $PublicKeyFile
        break
     }
    "SetMysqlPassword" { 
        Get-Configuration -ConfigFile $ConfigFile
        $s = Protect-PasswordByOpenSSLPublicKey -PublicKeyFile $PublicKeyFile
        $Global:configuration.MysqlPassword = $s
        $Global:configuration.PSObject.Properties.Remove('OsConfig')
        $Global:configuration | ConvertTo-Json -Depth 10 | Out-File $ConfigFile
        break
     }
    Default {
        "Unimplement action."
    }
}