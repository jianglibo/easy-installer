param (
    [Parameter(Mandatory = $true, Position = 0)][string]$PublicKeyFile,
    [Parameter(Mandatory = $false)]
    [ValidateSet("EncryptPassword")]
    [string]$Action="EncryptPassword"
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

. ($here | Join-Path -ChildPath "scripts" | Join-Path -ChildPath "common" | Join-Path -ChildPath "common-util.ps1")

switch ($Action) {
    "EncryptPassword" { 
        Protect-PasswordByOpenSSLPublicKey -PublicKeyFile $PublicKeyFile
        break
     }
    Default {
        "Unimplement action."
    }
}